# --- Base image ---
FROM node:18-alpine AS base
WORKDIR /app

# Native build deps (for canvas etc.)
RUN apk add --no-cache \
  libc6-compat \
  python3 \
  make \
  g++ \
  pixman-dev \
  cairo-dev \
  pango-dev \
  jpeg-dev \
  giflib-dev

# --- Install dependencies ---
FROM base AS deps
COPY . .
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# --- Build stage ---
FROM base AS build
COPY --from=deps /app /app
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
ENV NEXT_TELEMETRY_DISABLED=1

# ✅ Patch next.config.mjs to remove invalid `has` route entry
RUN if [ -f next.config.mjs ]; then \
  sed -i '/"has": \[\s*{ *type: *"host" *} *\]/d' next.config.mjs; \
  fi

RUN pnpm run build

# --- Runtime image ---
FROM node:18-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN apk add --no-cache libc6-compat

COPY --from=build /app/.next .next
COPY --from=build /app/public ./public
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/prisma ./prisma

RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

EXPOSE 8080
CMD ["pnpm", "start"]
