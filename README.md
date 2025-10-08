# CookCLI Docker Image

Docker image for [CookCLI], a CLI tool for managing Cooklang recipes with a
built-in web server.

## Features

- 🐳 Multi-architecture support: `linux/amd64` and `linux/arm64`
- 🔒 Non-root user (UID/GID 1000:1000)
- 🏔️ Based on Alpine Linux for minimal size
- ✅ Built-in health check
- 🔄 Automatic version detection (always uses latest CookCLI release)
- 📦 Automatic updates when new CookCLI versions are released
- 🎯 OCI compliant labels

## Quick Start

### Using Docker Compose (Recommended)

Create a `compose.yaml` file:

```yaml
services:
  cookcli:
    container_name: cookcli
    deploy:
      resources:
        limits:
          cpus: 0.10
          memory: 32M
    image: inigochoa/cookcli:latest
    ports:
      - 9080:9080
    restart: unless-stopped
    volumes:
      - ./recipes:/recipes

```

Then run:

```bash
docker compose up -d
```

### Using Docker CLI

```bash
docker run -d \
  --name cookcli \
  -p 9080:9080 \
  -v $(pwd)/recipes:/recipes \
  --cpus="0.10" \
  --memory="32m" \
  --restart unless-stopped \
  inigochoa/cookcli:latest
```

## Usage

Once running, access the web interface at:

```
http://localhost:9080
```

Place your `.cook` recipe files in the `./recipes` directory (or whichever
directory you mounted as a volume).

## Configuration

### Ports

The container exposes port `9080` by default. You can map it to any host port:

```yaml
ports:
  - "8080:9080"  # Access on http://localhost:8080
```

### Volumes

Mount your recipes directory to `/recipes` inside the container:

```yaml
volumes:
  - /path/to/your/recipes:/recipes
```

### User Permissions

The container runs as user `1000:1000`. Ensure your recipe files have
appropriate permissions:

```bash
chown -R 1000:1000 ./recipes
```

## Resource Limits

To prevent the container from consuming excessive system resources, you can set
CPU and memory limits.

### Docker Compose

```yaml
deploy:
  resources:
    limits:
      cpus: '0.10'      # 10% of 1 CPU
      memory: 32M       # 32MB RAM
```

### Docker CLI

```bash
docker run -d \
  --cpus="0.10" \
  --memory="32m" \
  ...
```

### Monitoring Resource Usage

```bash
# Real-time resource monitoring
docker stats cookcli

# Current usage snapshot
docker stats --no-stream cookcli
```

## Supported Tags

- `latest` - Latest stable version of CookCLI
- `0.18.1` - Specific version tags
- `0.18` - Minor version tags
- `0` - Major version tags

## Health Check

The image includes a built-in health check that verifies the HTTP server is
responding:

- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 5 seconds
- Retries: 3

## Building from Source

### Prerequisites

- Docker with BuildKit support
- Docker Buildx (for multi-architecture builds)

### Build with latest version (auto-fetched from GitHub)

```bash
./build.sh build
```

### Build with specific version

```bash
VERSION=0.18.1 ./build.sh build
```

### Test locally

```bash
./build.sh test
```

### Publish to Docker Hub

```bash
# Login first
docker login

# Publish latest version
./build.sh publish

# Or publish specific version
VERSION=0.18.0 ./build.sh publish
```

## Architecture

This image uses a multi-stage build process:

1. **Downloader stage**: Automatically fetches the latest CookCLI release from
   GitHub (or uses a specified version), downloads and extracts the appropriate
   binary for the target architecture
2. **Final stage**: Minimal Alpine-based image with only the binary and runtime
   dependencies

The version is determined at build time:
- If no `VERSION` is specified, it automatically queries GitHub API for the
  latest release
- If `VERSION` is specified, it uses that exact version

## Security

- Runs as non-root user (UID/GID 1000)
- Minimal attack surface (Alpine base)
- No unnecessary packages installed
- Automatic security updates via automated builds

## License

This Docker image is licensed under the MIT License. See [LICENSE] for details.

CookCLI itself is licensed under its own terms. See the [CookCLI] repository for
more information.

## Contributing

Issues and pull requests are welcome at [inigochoa/cookcli-docker].

## Credits

- CookCLI: https://github.com/cooklang/cookcli
- Cooklang: https://cooklang.org/

## Links

- Docker Hub: https://hub.docker.com/r/inigochoa/cookcli
- GitHub: https://github.com/inigochoa/cookcli-docker
- CookCLI Documentation: https://cooklang.org/cli/help/

[CookCLI]: https://github.com/cooklang/cookcli
[inigochoa/cookcli-docker]: https://github.com/inigochoa/cookcli-docker
[LICENSE]: LICENSE.md
