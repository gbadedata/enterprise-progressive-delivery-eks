FROM node:20-alpine AS dependencies
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force


FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=dependencies /app/node_modules ./node_modules
COPY src ./src

# Remove npm/npx/corepack from runtime image.
# The running container only needs the node binary and app files.
RUN rm -rf \
    /usr/local/lib/node_modules/npm \
    /usr/local/bin/npm \
    /usr/local/bin/npx \
    /usr/local/bin/corepack \
    /root/.npm \
    /tmp/*

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
