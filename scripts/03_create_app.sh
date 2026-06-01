#!/usr/bin/env bash
set -euo pipefail

echo "Creating Node.js application..."

cat > app/package.json <<'EOF'
{
  "name": "orders-api",
  "version": "1.0.0",
  "description": "Production-style API for progressive delivery on AWS EKS",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "test": "node --test tests/*.test.js",
    "lint": "node --check src/server.js"
  },
  "dependencies": {
    "express": "^4.18.3",
    "prom-client": "^15.1.3",
    "uuid": "^9.0.1"
  },
  "devDependencies": {}
}
EOF

cat > app/src/server.js <<'EOF'
const express = require("express");
const client = require("prom-client");
const { v4: uuidv4 } = require("uuid");

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || "v1.0.0";
const DEPLOYMENT_COLOR = process.env.DEPLOYMENT_COLOR || "blue";
const FAIL_MODE = process.env.FAIL_MODE || "none";

client.collectDefaultMetrics();

const httpRequestsTotal = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status_code", "color", "version"]
});

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route", "status_code", "color", "version"],
  buckets: [0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5]
});

const ordersCreatedTotal = new client.Counter({
  name: "business_orders_created_total",
  help: "Total number of created orders",
  labelNames: ["color", "version"]
});

const orderFailuresTotal = new client.Counter({
  name: "business_order_failures_total",
  help: "Total number of failed order operations",
  labelNames: ["color", "version"]
});

const appInfo = new client.Gauge({
  name: "app_version_info",
  help: "Application version information",
  labelNames: ["color", "version"]
});

appInfo.set({ color: DEPLOYMENT_COLOR, version: APP_VERSION }, 1);

function log(level, message, meta = {}) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION,
    ...meta
  }));
}

app.use((req, res, next) => {
  const requestId = req.headers["x-request-id"] || uuidv4();
  req.requestId = requestId;
  res.setHeader("x-request-id", requestId);

  const start = process.hrtime.bigint();

  res.on("finish", () => {
    const durationSeconds = Number(process.hrtime.bigint() - start) / 1e9;
    const route = req.route?.path || req.path;

    httpRequestsTotal.inc({
      method: req.method,
      route,
      status_code: res.statusCode,
      color: DEPLOYMENT_COLOR,
      version: APP_VERSION
    });

    httpRequestDuration.observe({
      method: req.method,
      route,
      status_code: res.statusCode,
      color: DEPLOYMENT_COLOR,
      version: APP_VERSION
    }, durationSeconds);

    log("info", "request_completed", {
      request_id: requestId,
      method: req.method,
      path: req.path,
      status_code: res.statusCode,
      duration_ms: Math.round(durationSeconds * 1000)
    });
  });

  next();
});

function maybeFail(req, res, next) {
  if (FAIL_MODE === "error") {
    orderFailuresTotal.inc({ color: DEPLOYMENT_COLOR, version: APP_VERSION });
    return res.status(500).json({
      status: "error",
      message: "Controlled failure mode is active",
      color: DEPLOYMENT_COLOR,
      version: APP_VERSION
    });
  }

  if (FAIL_MODE === "partial" && Math.random() < 0.3) {
    orderFailuresTotal.inc({ color: DEPLOYMENT_COLOR, version: APP_VERSION });
    return res.status(500).json({
      status: "error",
      message: "Controlled partial failure occurred",
      color: DEPLOYMENT_COLOR,
      version: APP_VERSION
    });
  }

  if (FAIL_MODE === "slow") {
    return setTimeout(next, 1000);
  }

  next();
}

app.get("/live", (req, res) => {
  res.status(200).json({
    status: "alive",
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION
  });
});

app.get("/ready", (req, res) => {
  if (FAIL_MODE === "not-ready") {
    return res.status(503).json({
      status: "not_ready",
      color: DEPLOYMENT_COLOR,
      version: APP_VERSION
    });
  }

  res.status(200).json({
    status: "ready",
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION,
    fail_mode: FAIL_MODE
  });
});

app.get("/api/orders", maybeFail, (req, res) => {
  res.status(200).json({
    orders: [
      { id: "ord-001", item: "Laptop", status: "confirmed" },
      { id: "ord-002", item: "Monitor", status: "processing" }
    ],
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION
  });
});

app.post("/api/orders", maybeFail, (req, res) => {
  ordersCreatedTotal.inc({ color: DEPLOYMENT_COLOR, version: APP_VERSION });

  res.status(201).json({
    id: uuidv4(),
    status: "created",
    payload: req.body,
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION
  });
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

app.use((req, res) => {
  res.status(404).json({
    status: "not_found",
    path: req.path,
    color: DEPLOYMENT_COLOR,
    version: APP_VERSION
  });
});

app.listen(PORT, () => {
  log("info", "server_started", {
    port: PORT,
    fail_mode: FAIL_MODE
  });
});
EOF

cat > app/tests/health.test.js <<'EOF'
const test = require("node:test");
const assert = require("node:assert");

test("basic arithmetic sanity check", () => {
  assert.strictEqual(1 + 1, 2);
});
EOF

cat > app/Dockerfile <<'EOF'
FROM node:20-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

FROM node:20-alpine AS runtime
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=dependencies /app/node_modules ./node_modules
COPY package*.json ./
COPY src ./src

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/server.js"]
EOF

cat > app/.dockerignore <<'EOF'
node_modules
npm-debug.log
.git
.github
docs
terraform
k8s
EOF

echo "Application created."
