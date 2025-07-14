# --- Base image with necessary packages ---
FROM node:18-alpine AS base
WORKDIR /app

# Install common build deps and native module support (e.g. for canvas)
RUN apk add --no-cache \
  libc6-compat \
  python3 \
  make \
  g++ \
  pixman-dev \
  cairo-dev \
  pango-dev \
  jpeg-dev \
  giflib-dev \
  node-gyp

# --- Dependencies install ---
FROM base AS deps
COPY . .
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# --- Patch invalid 'has' object in next.config.mjs ---
RUN if [ -f next.config.mjs ]; then \
  sed -i 's/{ *type: *"host" *}/{ type: "host", value: ".*" }/g' next.config.mjs; \
  fi

# --- Build the application ---
FROM base AS build
COPY --from=deps /app /app
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# --- Final production image ---
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Minimal runtime deps
RUN apk add --no-cache libc6-compat

# Copy only necessary artifacts for runtime
COPY --from=build /app/.next .next
COPY --from=build /app/public ./public
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/prisma ./prisma

# Ensure pnpm is available at runtime if needed
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

EXPOSE 8080
CMD ["pnpm", "start"]
