# Lab 2 - multi-stage image for the counter app
#   base    : Python + runtime dependencies (cached until requirements.txt changes)
#   test    : adds pytest and runs the unit tests during the build
#   runtime : final image, copies app.py FROM the test stage, so the image
#             only builds if the tests pass

ARG BASE_IMAGE=python:3.12-slim

FROM ${BASE_IMAGE} AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM base AS test
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY pytest.ini app.py ./
COPY tests/ tests/
RUN pytest -q

FROM base AS runtime
ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}
RUN useradd --create-home --uid 10001 appuser
COPY --from=test /app/app.py .
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)" || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--access-logfile", "-", "app:app"]
