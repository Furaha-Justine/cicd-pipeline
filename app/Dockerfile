# ── Stage 1: test ─────────────────────────────────────────────────────────────
FROM node:18-alpine AS tester

WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm test

# ── Stage 2: production ────────────────────────────────────────────────────────
FROM node:18-alpine AS production

ENV NODE_ENV=production
WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --omit=dev

COPY index.js ./

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

USER node

CMD ["node", "index.js"]
