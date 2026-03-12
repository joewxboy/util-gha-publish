FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/open-horizon/gha-publish"
LABEL org.opencontainers.image.description="Publishes Open Horizon service definitions"

ARG HZN_CLI_VERSION=2.32.0-1759

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      jq && \
    curl -sSL "https://github.com/open-horizon/anax/releases/download/v${HZN_CLI_VERSION}/horizon-agent-linux-deb-amd64.tar.gz" \
      -o /tmp/horizon-agent.tar.gz && \
    tar -zxf /tmp/horizon-agent.tar.gz --wildcards -C /tmp 'horizon-cli_*.deb' && \
    apt-get install -y --no-install-recommends /tmp/horizon-cli_*.deb && \
    rm -rf /tmp/horizon-agent.tar.gz /tmp/horizon-cli_*.deb /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
