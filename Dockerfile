
FROM otel/opentelemetry-collector-contrib:0.165.0-nightly.5b35ef3

# Image metadata
LABEL org.opencontainers.image.title="OpenTelemetry Collector"
LABEL org.opencontainers.image.description="OpenTelemetry Collector Contrib for GCP monitoring"
LABEL org.opencontainers.image.vendor="OpenTelemetry"
LABEL org.opencontainers.image.source="https://github.com/open-telemetry/opentelemetry-collector-contrib"

# Run as a non-root user
USER 10001:10001
