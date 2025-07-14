# --- Base Image ---
FROM node:18-alpine AS base
WORKDIR /app

# --- Install deps ---
FROM base AS deps
RUN apk add --no-cache libc6-compat
COPY . .
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm install --no-frozen-lockfile
RUN pnpm prisma generate

# --- Build the app ---
FROM base AS build
COPY --from=deps /app /app
ENV NEXT_TELEMETRY_DISABLED=1
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate
RUN pnpm run build

# --- Production image ---
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Optionally re-enable pnpm for runtime (useful for start command)
RUN corepack enable && corepack prepare pnpm@8.6.6 --activate

COPY --from=build /app/.next .next
COPY --from=build /app/public ./public
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
COPY --from=build /app/prisma ./prisma

EXPOSE 8080
CMD ["pnpm", "start"]
