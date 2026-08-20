# CloudDrive

CloudDrive is a self-hosted cloud file storage platform — a Google Drive–style application for uploading, organizing, sharing, and managing files and folders. It includes role-based access control, public share links, starred items, trash with retention settings, and background job processing for async work.

## Features

- **File & folder management** — Create folders, upload files to S3, rename, move, preview (PDF, video, and more), and browse by drive view
- **Sharing & public access** — Share files and folders via short URLs; support for visitor/guest access
- **Favourites & trash** — Star items for quick access; soft-delete with configurable trash retention
- **Activity tracking** — File activity and recent-item views
- **Identity & RBAC** — User authentication, roles, permissions, and admin management
- **Async processing** — Transactional outbox pattern with BullMQ workers for background jobs

## Architecture

```text
┌─────────────┐     REST API      ┌──────────────┐     S3      ┌─────────┐
│   Frontend  │ ◄──────────────► │ FastAPI API  │ ◄─────────► │ AWS S3  │
│  Vue 3/Vite │                   │   (Python)   │             └─────────┘
└─────────────┘                   └──────┬───────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    │                    │                    │
               PostgreSQL              Redis              RabbitMQ
                    │                    │
                    └──────────►  BullMQ Worker  ◄──────────┘
                                   (TypeScript)
```

The repo is a **monorepo** that orchestrates two git submodules:

| Path | Repository | Description |
|------|------------|-------------|
| `frontend/` | [clouddrive-frontend](https://github.com/Kapilrohilla/clouddrive-frontend) | Vue 3 SPA |
| `backend/` | [clouddrive-backend](https://github.com/Kapilrohilla/clouddrive-backend) | FastAPI REST API + TypeScript worker |

Additional top-level directories:

| Path | Description |
|------|-------------|
| `scripts/` | Dev tooling (e.g. one-command local startup) |
| `infra/` | Terraform for AWS (VPC, EC2, S3) |
| `observability/` | Observability stack (planned) |

## Tech stack

**Frontend** — Vue 3, Vite, TypeScript, Pinia, Vue Router, TanStack Query, PrimeVue

**Backend API** — Python 3.12+, FastAPI, SQLAlchemy (async), PostgreSQL, Redis, JWT auth, boto3 (S3)

**Worker** — TypeScript, BullMQ, PostgreSQL outbox poller, ioredis

**Infrastructure** — Docker Compose (local), Terraform + AWS (deploy)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) — Postgres, Redis, RabbitMQ
- [Python 3.12+](https://www.python.org/downloads/)
- [Node.js](https://nodejs.org/) `^22.18.0` or `>=24.12.0` (see `frontend/package.json`)
- [AWS credentials](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) — S3 bucket for file storage (required for uploads)

## Quick start

From the repo root, run the dev script. It initializes submodules, starts Docker services, creates `.env` files from examples, installs dependencies, and launches both servers:

```bash
./scripts/run-dev.sh
```

| Service | URL |
|---------|-----|
| Frontend | http://127.0.0.1:5173 |
| Backend API | http://127.0.0.1:8000 |
| API docs (Swagger) | http://127.0.0.1:8000/docs |
| RabbitMQ management | http://127.0.0.1:15672 |

Press `Ctrl+C` to stop the app servers. Docker containers keep running until you stop them manually:

```bash
docker compose -f backend/docker-compose.yaml down
```

Override ports if needed:

```bash
BACKEND_PORT=8080 FRONTEND_PORT=3000 ./scripts/run-dev.sh
```

## Manual setup

### 1. Clone with submodules

```bash
git clone --recurse-submodules <repo-url>
cd cloud-drive-mono-repo

# Or, if already cloned:
git submodule update --init --recursive
```

### 2. Start infrastructure

```bash
docker compose -f backend/docker-compose.yaml up -d
```

This starts **PostgreSQL** (5432), **Redis** (6379), and **RabbitMQ** (5672 / management UI 15672).

### 3. Backend API

```bash
cd backend
cp .env.example .env   # edit with your AWS keys and secrets
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
fastapi dev app/main.py --host 127.0.0.1 --port 8000
```

Key environment variables in `backend/.env`:

| Variable | Description |
|----------|-------------|
| `DB_URL` | PostgreSQL connection string |
| `AWS_API_KEY` / `AWS_SECRET_KEY` / `AWS_S3_BUCKET` | S3 storage |
| `JWT_SECRET` | Token signing secret |
| `REDIS_URL` | Redis connection |
| `HOST_URL` / `FRONTEND_URL` | Backend and frontend base URLs |

Schema migrations run automatically on API startup.

### 4. Frontend

```bash
cd frontend
cp .env.example .env
npm install --legacy-peer-deps
npm run dev
```

Set `VITE_BACKEND_URL` in `frontend/.env` to point at the API (default: `http://localhost:8000`).

### 5. Background worker (optional)

The worker polls the transactional outbox and processes jobs via BullMQ (file/folder events, etc.):

```bash
cd backend/worker
cp .env.example .env
pnpm install
npx tsx index.ts
```

Configure `DATABASE_URL` and `REDIS_CONNECTION_STRING` in `backend/worker/.env`.

## Project structure

```text
cloud-drive-mono-repo/
├── backend/                 # FastAPI API (git submodule)
│   ├── app/
│   │   ├── api/v1/          # REST endpoints (auth, files, folders, rbac, …)
│   │   ├── services/        # Business logic
│   │   ├── models/          # SQLAlchemy models
│   │   └── infra/           # Database, queue, migrations
│   ├── worker/              # BullMQ outbox worker (TypeScript)
│   └── docker-compose.yaml  # Local Postgres, Redis, RabbitMQ
├── frontend/                # Vue 3 SPA (git submodule)
│   └── src/
│       ├── views/           # My Drive, Starred, Trash, Recent, …
│       ├── components/      # Drive UI, previews, modals
│       └── services/        # API clients, upload manager
├── infra/                   # Terraform (AWS VPC, EC2, S3)
├── scripts/                 # run-dev.sh
└── observability/           # Observability config (planned)
```

## API overview

All authenticated routes are under `/api`. Notable endpoint groups:

- `/api/auth` — Login, registration, session
- `/api/files`, `/api/folders` — CRUD, upload, trash
- `/api/favourites` — Starred items
- `/api/public`, `/api/visitor` — Public and guest access
- `/api/rbac`, `/api/users` — Roles, permissions, user admin
- `/api/config` — App configuration (e.g. trash retention)

See interactive docs at `/docs` when the API is running.

## Infrastructure (Terraform)

AWS resources for deployment live in `infra/`:

- S3 bucket for file storage (versioned, private)
- VPC, subnets, and EC2 for hosting
- Remote state in S3 (`ap-south-1`)

```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Development

**Backend linting** — Ruff (config in `backend/pyproject.toml`)

**Frontend** — ESLint, Oxlint, Prettier

```bash
cd frontend
npm run lint
npm run build
```

**Backend tests**

```bash
cd backend
source .venv/bin/activate
pytest
```

## License

Private project. See individual submodule repositories for their licenses.
