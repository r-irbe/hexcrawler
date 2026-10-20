# hexcrawler User Guide

Horizontal-scale TypeScript web crawler built on hexagonal architecture, BullMQ priority queues, RFC 6890 SSRF-safe redirects, per-domain circuit breakers, and typed `Result<T, E>` error handling.

---

## 1. Prerequisites

- **Node.js**: `>= 22.0.0` (see `.nvmrc`)
- **Package Manager**: `pnpm >= 10.33.0`
- **Container Runtime** (optional, for local stack / integration tests): Docker & Docker Compose
- **Kubernetes Local Cluster** (optional, for k3d E2E & chaos tests): `k3d`, `kubectl`, `k6`

---

## 2. Installation & Verification

Clone and build all 19 workspace packages:

```bash
pnpm install
pnpm build
```

Run the unit and property-based test suites (no external infrastructure required):

```bash
pnpm test
```

Run the full static and test verification guard chain (`typecheck` -> `lint` -> `test`):

```bash
pnpm verify:guards
```

---

## 3. Running the Crawler Locally (Docker Compose)

Launch the complete stack (PostgreSQL, Dragonfly/Redis, MinIO, Crawler workers, 7-page Web Simulator, Prometheus, Grafana, Jaeger, and Loki):

```bash
docker compose -f infra/docker/docker-compose.dev.yml --profile demo up
```

### Local Endpoints

| Service | Endpoint | Description |
| :--- | :--- | :--- |
| **API Gateway** | `http://localhost:8081` | Health (`/health`), readiness (`/readyz`), crawl REST/tRPC API |
| **Prometheus Metrics** | `http://localhost:9090/metrics` | Crawler worker & frontier metrics |
| **Web Simulator** | `http://localhost:8080` | Target synthetic site for demo crawls |
| **Grafana** | `http://localhost:3000` | 7 pre-provisioned dashboards (start with *hexcrawler Overview*) |
| **Jaeger UI** | `http://localhost:16686` | End-to-end distributed traces across DNS, SSRF guard, fetch, and parse |
| **Prometheus UI** | `http://localhost:9091` | 12 alert rules and scrape target status |
| **MinIO Console** | `http://localhost:9001` | Stored page blobs (`minioadmin` / `minioadmin`) |

---

## 4. HTTP API Reference

The API Gateway exposes OpenAPI 3.1 (generated from TypeSpec in `specs/`) and tRPC endpoints:

### Start a Crawl Session

```bash
curl -X POST http://localhost:8081/api/v1/crawls \
  -H "Content-Type: application/json" \
  -d '{
    "seedUrls": ["http://simulator:8080/"],
    "maxDepth": 3,
    "maxPages": 500
  }'
```

### Query Crawl Status & Results

```bash
# Check crawl progress
curl http://localhost:8081/api/v1/crawls/<crawl-id>

# Retrieve crawled page metadata and storage keys
curl http://localhost:8081/api/v1/crawls/<crawl-id>/results

# Cancel an active crawl
curl -X DELETE http://localhost:8081/api/v1/crawls/<crawl-id>
```

---

## 5. Configuration & Resilience Controls

Workers and frontier services are configured via Zod-validated environment variables (`packages/config/`):

- **SSRF Protection (`packages/ssrf-guard`)**: Every initial URL and HTTP redirect hop is resolved and checked against RFC 6890 private/reserved ranges (`10.0.0.0/8`, `127.0.0.0/8`, `169.254.0.0/16`, `172.16.0.0/12`, `192.168.0.0/16`, CGNAT, and IPv4-mapped IPv6).
- **Resilience Stack (`packages/resilience`)**: 7-layer `cockatiel` pipeline per domain:
  1. Per-domain circuit breaker (opens on consecutive 5xx/timeouts, transitions to half-open after cooldown)
  2. Exponential backoff retry with jitter
  3. Request timeout enforcement
  4. Bulkhead concurrency isolation
  5. Local token bucket rate limiter
  6. Distributed Redis Lua sliding-window rate limiter
  7. Graceful fallback handler
- **Typed Error Handling (`packages/core`)**: All domain and adapter operations return `neverthrow` `Result<T, DomainError>` values rather than throwing exceptions.

---

## 6. Kubernetes (k3d), Load Testing, and Chaos Engineering

### Full k3d Cluster Lifecycle

```bash
scripts/setup-local.sh        # Provision k3d cluster, ArgoCD, Chaos Mesh, and observability stack
scripts/run-k8s-e2e-test.sh   # Run 5-phase E2E suite (simulator, monitoring, scale up/down, chaos)
scripts/teardown-local.sh     # Tear down cluster
```

### Mega Simulator & Load Profiles

Run the synthetic 1,000-domain x 50-page simulator with injected failure modes (slow responses, 5xx errors, 5-hop redirect chains, intermittent drops, and 429 rate limits):

```bash
DOMAIN_COUNT=100 PAGES_PER_DOMAIN=20 \
  npx tsx packages/testing/src/simulators/mega-simulator-entrypoint.ts
```

Execute `k6` load and backpressure tests:

```bash
pnpm k6:load                  # 100 URL/s sustained throughput SLO verification
pnpm k6:backpressure          # 10,000 URL burst backpressure test
scripts/run-chaos-test.sh     # 25-minute Chaos Mesh fault-injection sequence
scripts/run-autoscale-test.sh # HPA pod scaling ramp (50 -> 250 -> 500 URL/s)
```

---

## 7. Further Reading

- [Architecture Overview](docs/ARCHITECTURE.md)
- [Getting Started Guide](docs/GETTING-STARTED.md)
- [Load & Chaos Testing Guide](docs/LOAD-TESTING.md)
- [Architecture Decision Records (ADRs)](docs/adr/)
- [Feature Specifications](docs/specs/)
