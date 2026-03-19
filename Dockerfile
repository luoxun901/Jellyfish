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
    TZ=Asia/Shanghai

WORKDIR /app

# Install uv (copy binary directly - fastest method)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Install backend dependencies using uv export + pip
# This is the most reliable approach for Docker
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv export --frozen --no-dev --no-hashes -o requirements.txt \
    && pip install --no-cache-dir -r requirements.txt \
    && rm requirements.txt

# Copy backend source
COPY backend/app ./app
COPY backend/init_db.py backend/init_storage.py ./

# Copy frontend build output
COPY --from=frontend-builder /build/front/dist ./static

# Create data directories
RUN mkdir -p /app/data

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
