# --- Base ---
FROM node:18-alpine

WORKDIR /app

# System deps for native modules
RUN apk add --no-cache libc6-compat python3 make g++ cairo-dev pango-dev jpeg-dev giflib-dev pixman-dev

# Copy code
COPY . .

# Enable pnpm
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

# Install deps
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# 🔥 Minimal patch: Remove the invalid `has` block (no attempt to fix)
RUN sed -i '/"has": \[{ *type: *"host" *}\],*/d' next.config.mjs || true

# Build the app
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# Expose port for Cloud Run
EXPOSE 8080

# Start the server
CMD ["pnpm", "start"]
