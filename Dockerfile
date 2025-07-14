# Base image (Debian-based for better native support)
FROM node:18-slim

# Set working directory
WORKDIR /app

# Install system dependencies for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    libcairo2-dev \
    libjpeg-dev \
    libpango1.0-dev \
    libgif-dev \
    librsvg2-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy all code
COPY . .

# Enable and install pnpm
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# Cleanly patch invalid "has" route in next.config.mjs
RUN sed -i '/"has": \[{ *type: *"host" *}\],*/d' next.config.mjs || true

# Disable telemetry and build
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# Expose port for GCP Cloud Run
EXPOSE 8080

# Start the app
CMD ["pnpm", "start"]
