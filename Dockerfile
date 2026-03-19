# ── Stage 1: Build frontend ──
FROM node:22-alpine AS frontend-builder
WORKDIR /build/front

# Install pnpm
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

# Install uv
RUN pip install --no-cache-dir uv

# Install backend dependencies
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project --active

# Copy backend source
COPY backend/app ./app
COPY backend/init_db.py backend/init_storage.py ./

# Copy frontend build output
COPY --from=frontend-builder /build/front/dist ./static

# Create data directories
RUN mkdir -p /app/data

EXPOSE 8000

# Start: use PORT env from Railway if available, default 8000
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
