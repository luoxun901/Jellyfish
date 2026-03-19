# ── Stage 1: Build frontend ──
FROM node:22-alpine AS frontend-builder
WORKDIR /build/front

RUN corepack enable && corepack prepare pnpm@latest --activate

COPY front/package.json front/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY front/ ./
RUN pnpm run build

# ── Stage 2: Backend + serve frontend ──
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Asia/Shanghai \
    UV_SYSTEM_PYTHON=1

WORKDIR /app

# Install uv (fast Python package installer)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install backend dependencies (system-wide, no venv)
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv pip install --no-cache -r pyproject.toml

# Copy backend source
COPY backend/app ./app
COPY backend/init_db.py backend/init_storage.py ./

# Copy frontend build output
COPY --from=frontend-builder /build/front/dist ./static

# Create data directories
RUN mkdir -p /app/data

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
