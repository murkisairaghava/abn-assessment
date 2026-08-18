FROM python:3.12-slim

LABEL org.opencontainers.image.title="shows-api" \
    org.opencontainers.image.description="FastAPI shows API for AKS assessment"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

# Create an unprivileged user for runtime security on AKS.
RUN groupadd --system --gid 10001 appgroup \
    && useradd --system --uid 10001 --gid appgroup --create-home --home-dir /home/appuser appuser

COPY --chown=appuser:appgroup app.py .

USER appuser

# Kubernetes readiness/liveness probes should target GET /health on port 8080.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)"

EXPOSE 8080

STOPSIGNAL SIGTERM

CMD ["python", "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers"]
