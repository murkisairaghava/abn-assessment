import json
import logging
import os
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import requests
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient, BlobServiceClient
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("shows-api")


@dataclass(frozen=True)
class TVMazeConfig:
    base_url: str = "https://api.tvmaze.com/search/shows"
    timeout_seconds: int = 10


@dataclass(frozen=True)
class BlobStorageConfig:
    storage_account_url: str = ""
    container_name: str = "cache"
    cache_ttl_hours: int = 24
    enabled: bool = False


class BlobStorageCache:
    """Cache implementation using Azure Blob Storage with Managed Identity."""

    def __init__(self, config: BlobStorageConfig) -> None:
        self._config = config
        self._credential = DefaultAzureCredential()
        if config.enabled and config.storage_account_url:
            self._blob_service_client = BlobServiceClient(
                account_url=config.storage_account_url,
                credential=self._credential,
            )
            logger.info("Blob Storage cache initialized for account: %s", config.storage_account_url)
        else:
            self._blob_service_client = None
            logger.info("Blob Storage cache disabled")

    def _get_blob_name(self, query: str) -> str:
        """Generate blob name from query."""
        return f"shows_{query.lower().replace(' ', '_')}.json"

    def _is_expired(self, cached_data: dict[str, Any]) -> bool:
        """Check if cached data is expired based on TTL."""
        if "timestamp" not in cached_data:
            return True
        cached_time = datetime.fromisoformat(cached_data["timestamp"])
        expiry_time = cached_time + timedelta(hours=self._config.cache_ttl_hours)
        is_expired = datetime.now(timezone.utc) > expiry_time
        if is_expired:
            logger.info("Cache expired for blob: %s", cached_data.get("query", "unknown"))
        return is_expired

    def get(self, query: str) -> Optional[dict[str, Any]]:
        """Retrieve cached data from Blob Storage if it exists and is not expired."""
        if not self._blob_service_client:
            return None

        blob_name = self._get_blob_name(query)
        try:
            blob_client = self._blob_service_client.get_blob_client(
                container=self._config.container_name,
                blob=blob_name,
            )
            download_stream = blob_client.download_blob()
            cached_data = json.loads(download_stream.readall())
            if not self._is_expired(cached_data):
                logger.info("Cache hit for query: %s", query)
                return cached_data.get("results")
            else:
                logger.info("Cache expired for query: %s, removing blob", query)
                blob_client.delete_blob()
        except Exception as exc:
            logger.debug("Cache miss or error for query=%s: %s", query, exc)
        return None

    def put(self, query: str, results: list[dict[str, Any]]) -> None:
        """Store results in Blob Storage."""
        if not self._blob_service_client:
            return

        blob_name = self._get_blob_name(query)
        try:
            cache_data = {
                "query": query,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "results": results,
            }
            blob_client = self._blob_service_client.get_blob_client(
                container=self._config.container_name,
                blob=blob_name,
            )
            blob_client.upload_blob(json.dumps(cache_data), overwrite=True)
            logger.info("Cached results for query: %s", query)
        except Exception as exc:
            logger.warning("Failed to cache results for query=%s: %s", query, exc)


class TVMazeClient:
    def __init__(self, config: TVMazeConfig, client_session: requests.Session) -> None:
        self._config = config
        self._session = client_session

    def search_shows(self, query: str) -> list[dict[str, Any]]:
        response = self._session.get(
            self._config.base_url,
            params={"q": query},
            timeout=self._config.timeout_seconds,
        )
        response.raise_for_status()
        payload: list[dict[str, Any]] = response.json()
        return payload


class ShowsService:
    def __init__(self, client: TVMazeClient, cache: Optional[BlobStorageCache] = None) -> None:
        self._client = client
        self._cache = cache

    def get_shows(self, query: str) -> dict[str, Any]:
        # Step 1: Check cache
        if self._cache:
            cached_results = self._cache.get(query)
            if cached_results is not None:
                logger.info("Returning cached results for query: %s", query)
                return {"query": query, "results": cached_results, "source": "cache"}

        # Step 2: Call TVMaze if not cached
        logger.info("Fetching fresh data from TVMaze for query: %s", query)
        results = self._client.search_shows(query)

        # Step 3: Store in cache
        if self._cache:
            self._cache.put(query, results)

        return {"query": query, "results": results, "source": "tvmaze"}


class HealthResponse(BaseModel):
    status: str


class ShowsResponse(BaseModel):
    query: str
    results: list[dict[str, Any]]
    source: str = "tvmaze"  # "cache" or "tvmaze"


def _build_session() -> requests.Session:
    req_session = requests.Session()
    retry = Retry(
        total=2,
        backoff_factor=0.2,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"],
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry, pool_connections=20, pool_maxsize=20)
    req_session.mount("https://", adapter)
    req_session.mount("http://", adapter)
    return req_session


app = FastAPI(title="shows-api")
api_session = _build_session()

# Initialize Blob Storage cache with Managed Identity
blob_storage_config = BlobStorageConfig(
    storage_account_url=os.getenv("STORAGE_ACCOUNT_URL", ""),
    container_name=os.getenv("CACHE_CONTAINER_NAME", "cache"),
    cache_ttl_hours=int(os.getenv("CACHE_TTL_HOURS", "24")),
    enabled=os.getenv("BLOB_STORAGE_ENABLED", "false").lower() == "true",
)
blob_storage_cache = BlobStorageCache(blob_storage_config) if blob_storage_config.enabled else None

service = ShowsService(
    TVMazeClient(TVMazeConfig(), client_session=api_session),
    cache=blob_storage_cache,
)


@app.on_event("shutdown")
def shutdown() -> None:
    api_session.close()
    logger.info("HTTP session closed")


@app.get(
    "/health",
    response_model=HealthResponse,
    status_code=200,
    summary="AKS liveness/readiness probe endpoint",
)
def health() -> HealthResponse:
    # Keep this endpoint fast and dependency-free for Kubernetes probes.
    return HealthResponse(status="ok")


@app.get("/api/shows", response_model=ShowsResponse)
def get_shows(query: str = Query(default="girls", min_length=1, max_length=100)) -> ShowsResponse:
    cleaned_query = query.strip()
    logger.info("Fetching shows from TVMaze for query=%s", cleaned_query)
    try:
        return ShowsResponse(**service.get_shows(cleaned_query))
    except requests.HTTPError as exc:
        logger.exception("TVMaze returned non-success response for query=%s", cleaned_query)
        raise HTTPException(status_code=502, detail="TVMaze API returned an error") from exc
    except requests.RequestException as exc:
        logger.exception("TVMaze request failed for query=%s", cleaned_query)
        raise HTTPException(status_code=502, detail="Unable to reach TVMaze API") from exc
    except Exception as exc:
        logger.exception("Unhandled error while processing /api/shows")
        raise HTTPException(status_code=500, detail="Internal server error") from exc
