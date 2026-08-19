# shows-api

Minimal FastAPI service for infrastructure assessment scenarios.

## Endpoints

- `GET /health`
  - Returns service health status.
- `GET /api/shows?query=<term>`
  - Calls TVMaze Search API and returns JSON response.
  - Default query is `girls` if `query` is not provided.

## Design (minimal clean architecture)

- API layer:
  - FastAPI route handlers in `app.py`
- Service layer:
  - `ShowsService` for application behavior
- Infrastructure/client layer:
  - `TVMazeClient` for outbound HTTP calls
- Config model:
  - `TVMazeConfig` for endpoint/timeout

## Logging and error handling

- Structured application logging is enabled using Python `logging`.
- TVMaze API errors are handled and returned as `502` responses.

## Local run

```bash
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8080
```

## Docker run

```bash
docker build -t shows-api .
docker run --rm -p 8080:8080 shows-api
```
