# 06 — Database Setup

## Local Development with Docker Compose

For local development, we use PostgreSQL 16 running in Docker Compose. This ensures consistent environments across developers.

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop) or Docker Engine + Docker Compose

### Starting the Database

From the project root:

```sh
docker-compose up -d postgres
```

This starts a PostgreSQL 16 container with:
- **Database**: `data_symphony_dev`
- **Username**: `postgres`
- **Password**: `postgres`
- **Port**: `5432`

The container will be ready when the healthcheck passes (typically 5-10 seconds).

### Creating and Migrating the Database

```sh
# Create the database and run migrations
mix ecto.create
mix ecto.migrate

# Or use the setup alias
mix setup
```

### Resetting the Database

To drop and recreate the database:

```sh
mix ecto.reset
```

### Stopping the Database

```sh
docker-compose down
```

To also remove the volume (clearing all data):

```sh
docker-compose down -v
```

## Production with Neon

For production, we use [Neon](https://neon.tech), a serverless PostgreSQL platform.

### Setup

1. Create an account at [neon.tech](https://neon.tech)
2. Create a project and note your connection string
3. Set the `DATABASE_URL` environment variable in your production deployment:

```
DATABASE_URL=postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require
```

For Fly.io deployments, set this secret via:

```sh
fly secrets set DATABASE_URL="postgresql://..."
```

### Connection Details

Neon provides a project in the format:
- Host: `ep-xxxxx.region.neon.tech`
- Database: Usually `neondb`
- User: Auto-generated (e.g., `neondb_owner`)
- Password: Provided during setup

**Important**: Never commit the `DATABASE_URL` to source control. Always use environment variables or a secret manager.

### SSL Requirements

Neon requires SSL connections. The connection string above includes `sslmode=require`. Ensure `runtime.exs` properly handles this:

```elixir
config :data_symphony, DataSymphony.Repo,
  url: database_url,
  ssl: true,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6
```

### Migrations in Production

Migrations are run automatically during deployment via the release script. Ensure your CI/CD pipeline runs the release task.

## Environment Variables Reference

| Variable | Development | Test | Production |
|----------|-------------|------|------------|
| `DATABASE_URL` | Not set (uses config/dev.exs) | Not set (uses config/test.exs) | Required |
| `ECTO_IPV6` | Not set | Not set | Optional (set to "true" for IPv6) |
| `POOL_SIZE` | 10 | 2*cores | Configurable (suggest 10-20) |

## Testing

Database tests use `Ecto.Adapters.SQL.Sandbox` for isolation:

```sh
mix test
```

The test database is automatically created/migrated before running tests.
