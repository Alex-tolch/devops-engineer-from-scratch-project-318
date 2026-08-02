### Hexlet tests and linter status

[![Actions Status](https://github.com/Alex-tolch/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Alex-tolch/devops-engineer-from-scratch-project-318/actions)

## Deploy (Hexlet)

Fork of [hexlet-components/project-devops-deploy](https://github.com/hexlet-components/project-devops-deploy) with Docker, CI, Terraform (DigitalOcean), Ansible.

| Item | Location |
|------|----------|
| Ansible | [`ansible/`](ansible/) |
| Terraform | [`terraform/`](terraform/) |
| App URL | http://104.248.240.149:8080 |

```bash
make test
make docker-build
make compose-up
DO_TOKEN=... bash scripts/do-provision.sh   # optional
cp ansible/inventory.ini.example ansible/inventory.ini
make server-prepare && make server-deploy
```

**Updating the app on the droplet:** `make server-deploy` alone does not replace the image if GHCR pull is denied (private package). Build locally and load over SSH, then recreate the container:

```bash
make docker-upload-server
# or: NO_CACHE=1 make docker-upload-server   # full rebuild
```

```bash
curl -s "http://104.248.240.149:8080/api/bulletins?page=1&perPage=3"
# Production metrics (Nginx basic auth; password in ansible vault):
curl -s -u "metrics:<password>" "http://104.248.240.149:9090/actuator/health"
curl -s -u "metrics:<password>" "http://104.248.240.149:9090/actuator/prometheus" | head
# Node Exporter (firewall: monitoring sources only; from allowed IP):
curl -s "http://104.248.240.149:9100/metrics" | head
```

## Observability (step 2): Node Exporter and application metrics

Ansible installs **Node Exporter** and an **Nginx** reverse proxy in front of Spring Actuator. The app publishes management on **`127.0.0.1:9091`** (container port 9090); Nginx listens on **`0.0.0.0:9090`** with **HTTP basic auth** and **JSON access/error logs** (`/var/log/nginx/metrics-access.json`, `metrics-error.log`). Host port 9090 cannot be shared with Docker `0.0.0.0`/`127.0.0.1:9090` bind — use 9091 for the container publish.

| Component | Port | Access |
|-----------|------|--------|
| HTTP API | 8080 | Public (DO firewall) |
| Actuator via Nginx | 9090 | `metrics_source_addresses` in Terraform + basic auth (`metrics` user, password in vault) |
| Node Exporter | 9100 | `metrics_source_addresses` only (no auth; restrict by firewall) |

Terraform variable `metrics_source_addresses` (default `0.0.0.0/0` for labs) controls inbound **9090** and **9100**. Set to your monitoring server `/32` in `terraform.tfvars`:

```hcl
metrics_source_addresses = ["203.0.113.50/32"]
```

Inventory and vars: [`ansible/inventory.ini.example`](ansible/inventory.ini.example), [`ansible/group_vars/app/vars.yml`](ansible/group_vars/app/vars.yml). Add `vault_metrics_basic_auth_password` in encrypted [`ansible/group_vars/app/vault.yml`](ansible/group_vars/app/vault.yml) (see `vault.yml.example`).

Deploy monitoring stack:

```bash
make server-prepare          # first install
make ansible-monitoring      # after config changes
```

### Verification (`<app-host>` = droplet IP)

Local/docker (no Nginx, direct Actuator):

```bash
curl -s http://localhost:9090/actuator/health
curl -s http://localhost:9090/actuator/prometheus | head
```

Production (via Nginx on 9090):

```bash
export APP_HOST=104.248.240.149
export METRICS_PASS='your-vault-password'
curl -s -u "metrics:${METRICS_PASS}" "http://${APP_HOST}:9090/actuator/health"
curl -s -u "metrics:${METRICS_PASS}" "http://${APP_HOST}:9090/actuator/prometheus" | grep -E '^(process_uptime|http_server_requests)' | head
curl -s "http://${APP_HOST}:9100/metrics" | grep -E '^node_load1|^node_memory_MemAvailable_bytes' | head
```

### Required Prometheus metrics (host + application)

| Metric | Source | Category |
|--------|--------|----------|
| `node_load1` | Node Exporter | CPU load |
| `node_cpu_seconds_total` | Node Exporter | CPU |
| `node_memory_MemAvailable_bytes` | Node Exporter | Memory |
| `node_memory_MemTotal_bytes` | Node Exporter | Memory |
| `node_filesystem_avail_bytes` | Node Exporter | Disks |
| `node_filesystem_size_bytes` | Node Exporter | Disks |
| `node_network_receive_bytes_total` | Node Exporter | Network |
| `node_network_transmit_bytes_total` | Node Exporter | Network |
| `node_procs_running` | Node Exporter | Processes |
| `node_systemd_unit_state` | Node Exporter (`--collector.systemd`) | System services |
| `process_uptime_seconds` | Actuator `/actuator/prometheus` | JVM / app process |
| `jvm_memory_used_bytes` | Actuator | JVM memory |
| `http_server_requests_seconds_count` | Actuator | HTTP traffic |
| `http_server_requests_seconds_sum` | Actuator | HTTP latency |
| `http_server_requests_seconds_bucket` | Actuator | HTTP histogram |

Collectors enabled in Ansible: `systemd`, `processes`. Application metrics use Micrometer Prometheus registry (Spring Boot Actuator).

---

# Project DevOps Deploy

Bulletin board service.

> **Fork policy**: this upstream repository is read-only. We do not review or merge pull requests and we do not accept infrastructure changes (Dockerfiles, Ansible roles, CI/CD workflows, etc.). To experiment or extend the project, fork it and work inside your own repository.

The default `dev` profile uses an in-memory H2 database and seeds 10 sample bulletins through `DataInitializer`, so the API works immediately after startup.

API documentation is available via Swagger UI at `http://localhost:8080/swagger-ui/index.html`.

## Project layout

- Backend (Spring Boot) lives in the repository root.
- Frontend (React Admin + Vite) is located in `frontend/`.
- Shared static assets for the backend are served from `src/main/resources/static` (populated by the frontend build when needed).

Keep this structure in mind when running commands—backend tooling (`gradlew`, `make run`, tests) run from the root, frontend tooling (`npm`, `vite`) runs from `frontend/`.

## Environment variables

Key variables are read directly by Spring Boot (see `src/main/resources/application.yml` and `application-prod.yml` for defaults):

| Variable                     | Description                                                   | Default                                      |
|------------------------------|---------------------------------------------------------------|----------------------------------------------|
| `SPRING_PROFILES_ACTIVE`     | Active Spring profile (`dev`, `prod`, etc.)                   | `dev`                                        |
| `SPRING_DATASOURCE_URL`      | JDBC URL for PostgreSQL in `prod`                             | `jdbc:postgresql://localhost:5432/bulletins` |
| `SPRING_DATASOURCE_USERNAME` | DB username                                                   | `postgres`                                   |
| `SPRING_DATASOURCE_PASSWORD` | DB password                                                   | `postgres`                                   |
| `STORAGE_S3_BUCKET`          | Bucket name for bulletin images                               | empty                                        |
| `STORAGE_S3_REGION`          | Region for the S3-compatible storage                          | empty                                        |
| `STORAGE_S3_ENDPOINT`        | Optional custom endpoint                                      | empty                                        |
| `STORAGE_S3_ACCESSKEY`       | Access key ID                                                 | empty                                        |
| `STORAGE_S3_SECRETKEY`       | Secret key                                                    | empty                                        |
| `STORAGE_S3_CDNURL`          | Optional public CDN prefix                                    | empty                                        |
| `MANAGEMENT_SERVER_PORT`     | Port for Spring Actuator endpoints (health, metrics, etc.)    | `9090`                                       |
| `JAVA_OPTS`                  | Extra JVM parameters (heap, `-Dspring.profiles.active`, etc.) | empty                                        |

All other variables supported by Spring Boot can be overridden the same way; check the application configuration files if you need to confirm a property name.

## Requirements

- JDK 21+.
- Gradle 9.2.1.
- PostgreSQL only if you run the `prod` profile with an external database.
- Make.
- NodeJS 20+

## Running

### Backend (local dev profile)

1. Install prerequisites from the **Requirements** section.
2. From the repository root start the backend:

    ```bash
    make run
    ```

3. Explore the API:
   - `GET http://localhost:8080/api/bulletins`
   - `GET http://localhost:8080/api/bulletins?page=1&perPage=9&sort=createdAt&order=DESC&state=PUBLISHED&search=laptop`
   - Swagger UI: `http://localhost:8080/swagger-ui/index.html`

`/api/bulletins` accepts pagination (`page`, `perPage`), sorting (`sort`, `order`) and filters (`state`, `search`). Filters are processed via JPA Specifications so the same contract is available to the React Admin frontend.

### Frontend (development build)

1. Open a second terminal and move into the frontend directory:

    ```bash
    cd frontend
    make install   # npm install
    make start     # Vite dev server on http://localhost:5173
    ```

2. The dev server proxies `/api` requests to `http://localhost:8080`, so keep the backend running.

### Production profile on a single host

1. Export the environment variables from the table above (DB access, S3 storage, `JAVA_OPTS`, etc.). The defaults in `application-prod.yml` show the exact property names if you need to double-check.
2. Build and launch the backend:

    ```bash
    make build
    java -jar build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar
    ```

3. Serve the frontend either from the same JVM (see **Build and serve from the Java app**) or deploy it separately (any static hosting/CDN works once `frontend/dist` is uploaded).

`JAVA_OPTS` can be used to control heap size, GC, or add any `-D` system properties without editing the manifest.

### Useful commands

See [Makefile](./Makefile)

## Frontend

### Development

1. Install Node.js 24 LTS (or newer) and npm.
2. Install dependencies and start the Vite dev server:

    ```bash
    cd frontend
    make install
    make start
    ```

3. The dev server proxies `/api` requests to `http://localhost:8080`, so keep the backend running via `make run` (or `./gradlew bootRun`) in another terminal.

### Image upload flow

1. Upload files via `POST /api/files/upload` (multipart form field named `file`).
2. The response contains `key` and a temporary `url`. Persist the `key` in the `imageKey` field when creating or updating bulletins; the backend stores only that identifier.
3. When you need a fresh link, call `GET /api/files/view?key=...` to receive a new URL (the backend issues presigned links on demand).

### Build and serve from the Java app

1. Build the production bundle:

    ```bash
    cd frontend
    make install      # run once
    make build    # outputs to frontend/dist
    ```

2. Copy the compiled assets into Spring Boot’s static resources (served from `src/main/resources/static`):

    ```bash
    rm -rf src/main/resources/static
    mkdir -p src/main/resources/static
    cp -R frontend/dist/* src/main/resources/static/
    ```

3. Restart the backend (`make run`) and open `http://localhost:8080/` — the React app will now be served directly by the Java application.

### Running in Docker

Pass JVM flags via `JAVA_OPTS`:

```bash
docker run --rm -p 8080:8080 \
  -e JAVA_OPTS="-Xms256m -Xmx512m -Dspring.profiles.active=prod" \
  ...
```

Useful JVM options:

- `-Xms/-Xmx` — set memory limits inside the container.
- `-XX:+UseContainerSupport` / `-XX:ActiveProcessorCount` (these respect cgroup limits by default).
- `-Dspring.profiles.active=prod` — switch the profile without recompiling.
- `-Dlogging.level.root=INFO` or Spring environment variables (`SPRING_DATASOURCE_URL`, `STORAGE_S3_BUCKET`, etc.) — configure external services.

## Monitoring / management ports

Production (Ansible): Actuator is on **`127.0.0.1:9091`** on the host (Docker maps container `9090`); **Nginx** exposes **`0.0.0.0:9090`** with basic auth and JSON logs. **Node Exporter** listens on `9100`. Restrict both ports in Terraform (`metrics_source_addresses`).

Local development: management port is published on `9090` (`docker compose` / `make run`) without Nginx.

- Application HTTP: `8080`.
- Health: `/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness`.
- Prometheus scrape: `/actuator/prometheus` (Micrometer).
- See [Observability (step 2)](#observability-step-2-node-exporter-and-application-metrics) for curl examples and the metrics table.

## Actuator endpoints (local check)

With the app running locally (`make run`), the management port defaults to `http://localhost:9090`. Useful URLs:

- `http://localhost:9090/actuator` — index of exposed endpoints.
- `http://localhost:9090/actuator/health`, `/actuator/health/liveness`, `/actuator/health/readiness` — readiness/liveness probes.
- `http://localhost:9090/actuator/metrics` and `http://localhost:9090/actuator/metrics/http.server.requests` — raw Micrometer metrics.
- `http://localhost:9090/actuator/prometheus` — Prometheus scrape output (open in browser or `curl` to confirm it renders).
- `http://localhost:9090/actuator/logfile` — current application log (same JSON that goes to stdout).

Override the host/port with `MANAGEMENT_SERVER_PORT` if you changed it; no Prometheus or Grafana instance is needed just to inspect these endpoints.

## Logging

- The backend ships with `src/main/resources/logback-spring.xml`, which writes structured JSON events to `stdout`. Every record contains `timestamp`, `app`, `environment`, `instance`, `logger`, `thread`, message arguments, MDC, and stack traces so Promtail/Loki (or any log shipper) can parse them without extra processing.
- No extra variables are required, but you can supply a different configuration via Spring Boot’s standard options (`LOGGING_CONFIG`, `logging.config`, or by overriding `logback-spring.xml` on the classpath).
- Container runtimes should forward `stdout`/`stderr` to your logging pipeline. Avoid redirecting logs to files unless your platform explicitly demands it.

## Image Upload Checks

### Local (dev profile, H2 + temp storage)

1. Start backend: `make run` (uses in-memory H2 and local filesystem storage under `/tmp/bulletin-images`).
2. Start frontend dev server: `cd frontend && npm install && npm run dev`.
3. In React Admin:
    - Create a bulletin or edit an existing one.
    - Use the “Upload image” field; after save, the image preview should load via the generated `imageUrl`.
4. Verify backend log: look for `Stored image` entries or check `/tmp/bulletin-images` for a new file. Refresh the bulletin show page to ensure the presigned/local URL still renders.

### Production / S3

1. Ensure the S3-related variables from the table above (bucket, region, access/secret keys, optional endpoint/CDN URL) are exported alongside the `prod` profile settings.
2. Deploy backend (e.g., `java -jar build/libs/project-devops-deploy-0.0.1-SNAPSHOT.jar`).
3. In the frontend (local or deployed), upload an image for a bulletin.
4. Confirm expected behavior:
    - Response from `/api/files/upload` contains a non-empty `key`.
    - Image shows up in bulletin show view (URL should either point to CDN or be a presigned S3 link).
    - Object exists in S3 bucket (check via AWS console or `aws s3 ls s3://your-bucket/bulletins/...`).
5. Optional: run `curl -I "$(curl -s .../api/files/view?key=... | jq -r .url)"` to ensure the presigned URL is valid from the production environment.
