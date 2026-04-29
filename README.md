# Infrastructure as Code – Lekkeratlas

This repository contains the full infrastructure setup for Lekkeratlas using Docker Compose and Traefik.

It includes:
- Traefik (reverse proxy with automatic HTTPS)
- Backend service
- Frontend service
- RabbitMQ (internal queue)
- Authentik (authentication provider)
- PostgreSQL (separate databases for app + Authentik)

---

## Prerequisites

Make sure you have the following installed:

- Docker
- Docker Compose (v2)
- `openssl` (used for secret generation)

---

## Required setup

### 1. TransIP API key (for Let's Encrypt DNS challenge)

Place your private key at:

```
./traefik/transip.key
```

Make sure it has correct permissions:

```bash
chmod 600 ./traefik/transip.key
```

---

## Generate environment variables

Run the provided script:

```bash
./generate-env.sh
```

This will:
- Prompt you for required external configuration
- Generate secure random passwords for internal services
- Create a `.env` file
- Backup any existing `.env` automatically

⚠️ **Important:**
- Never commit `.env`
- Keep backups safe

---

## Start the stack

```bash
docker compose up -d
```

---

## Services

After startup, the following services should be available:

- Frontend: `https://lekkeratlas.nl`
- Backend API: `https://backend.lekkeratlas.nl`
- Authentik: `https://auth.lekkeratlas.nl`

---

## Debugging (optional)

Some services expose optional local-only ports for debugging (commented in `docker-compose.yml`).

Example:

```yaml
# RabbitMQ UI
# 127.0.0.1:15673:15672
```

Uncomment only when needed.

---

## Notes

- Internal services (RabbitMQ, databases) are **not publicly exposed**
- Authentik runs on its **own isolated database**
- Traefik handles all routing and HTTPS

---

## Common commands

```bash
# Stop everything
docker compose down

# Start containers
docker compose up -d

# View logs
docker compose logs -f
```

---

## Security

- All secrets are stored in `.env`
- Strong passwords are generated automatically
- Only Traefik is exposed publicly
