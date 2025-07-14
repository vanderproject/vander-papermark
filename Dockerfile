# --- Base image ---
FROM node:18-alpine AS base
WORKDIR /app

# Install build dependencies for native modules
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

# ✅ FIX: Patch next.config.mjs AFTER code is copied
RUN if [ -f next.config.mjs ]; then \
  node -e "const fs=require('fs'); \
    let c=fs.readFileSync('next.config.mjs','utf8'); \
    c=c.replace(/\\{\\s*type:\\s*['\\\"]host['\\\"]\\s*\\}/g,'{ type: \\\"host\\\", value: \\\".*\\\" }'); \
    fs.writeFileSync('next.config.mjs', c);" \
; fi

RUN pnpm run build

# --- Production stage ---
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

# Re-enable pnpm
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

EXPOSE 8080
CMD ["pnpm", "start"]
