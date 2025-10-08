# Stage 1: Download and extract CookCLI binary
FROM alpine:latest AS downloader

# Install download tools
RUN apk add --no-cache curl tar jq

# Build arguments
ARG TARGETARCH
ARG VERSION=latest

# Download the appropriate binary based on architecture
RUN ARCH_SUFFIX=""; \
    case "${TARGETARCH}" in \
        amd64) ARCH_SUFFIX="x86_64-unknown-linux-musl" ;; \
        arm64) ARCH_SUFFIX="aarch64-unknown-linux-musl" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    # Get latest version if VERSION is "latest" or empty
    if [ "${VERSION}" = "latest" ] || [ -z "${VERSION}" ]; then \
        echo "Fetching latest CookCLI version..."; \
        RESOLVED_VERSION=$(curl -s https://api.github.com/repos/cooklang/cookcli/releases/latest | jq -r '.tag_name' | sed 's/^v//'); \
    else \
        RESOLVED_VERSION="${VERSION}"; \
    fi && \
    echo "Using CookCLI version: ${RESOLVED_VERSION}" && \
    BINARY_NAME="cook-${ARCH_SUFFIX}.tar.gz" && \
    DOWNLOAD_URL="https://github.com/cooklang/cookcli/releases/download/v${RESOLVED_VERSION}/${BINARY_NAME}" && \
    echo "Downloading from: ${DOWNLOAD_URL}" && \
    curl -L -o /tmp/cook.tar.gz "${DOWNLOAD_URL}" && \
    tar -xzf /tmp/cook.tar.gz -C /tmp/ && \
    mv /tmp/cook /tmp/cookcli && \
    chmod +x /tmp/cookcli

# Verify the binary works
RUN /tmp/cookcli --version

# Stage 2: Final minimal image
FROM alpine:latest

# OCI Labels
LABEL org.opencontainers.image.title="CookCLI" \
      org.opencontainers.image.description="Docker image for CookCLI - CLI tool for managing Cooklang recipes" \
      org.opencontainers.image.url="https://github.com/inigochoa/cookcli-docker" \
      org.opencontainers.image.source="https://github.com/inigochoa/cookcli-docker" \
      org.opencontainers.image.vendor="Iñigo Ochoa" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.documentation="https://github.com/inigochoa/cookcli-docker/blob/main/README.md"

# Install minimal runtime dependencies
RUN apk add --no-cache ca-certificates curl

# Create non-root user with specific UID/GID
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory and adjust permissions
WORKDIR /recipes
RUN chown -R appuser:appuser /recipes

# Copy binary from downloader stage
COPY --from=downloader --chown=appuser:appuser /tmp/cookcli /usr/local/bin/cook

# Switch to non-root user
USER appuser

# Expose server port
EXPOSE 9080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:9080/ || exit 1

# Run the server
ENTRYPOINT ["cook", "server", ".", "--host"]
