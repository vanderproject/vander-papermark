# --- Base Image ---
FROM node:18-alpine AS base
WORKDIR /app

# Install system dependencies needed for node-gyp (for canvas)
RUN apk add --no-cache libc6-compat python3 make g++ pixman-dev cairo-dev pango-dev jpeg-dev giflib-dev

# --- Install deps ---
FROM base AS deps
COPY . .
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# --- Fix invalid Next.js rewrites before build ---
RUN if [ -f next.config.js ]; then \
    sed -i 's/{"type":"host"}/{"type":"host","value":".*"}/g' next.config.js; \
    fi

# --- Build the app ---
FROM base AS build
COPY --from=deps /app /app
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# --- Production image ---
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

# Enable pnpm in runtime image
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

EXPOSE 8080
CMD ["pnpm", "start"]
