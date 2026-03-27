FROM ubuntu:24.04

ARG TARGETARCH=amd64
ARG ARGO_WORKFLOWS_VERSION=v4.0.3

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    unzip \
    wget \
  && rm -rf /var/lib/apt/lists/*

# kubectl
RUN set -eux; \
    KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt); \
    curl -sLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl"; \
    chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Argo CD CLI
RUN curl -sLo /usr/local/bin/argocd \
      "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${TARGETARCH}" \
  && chmod +x /usr/local/bin/argocd

# Argo Workflows CLI (pinned to version used in Lab 2)
RUN curl -sLo /usr/local/bin/argo \
      "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/argo-linux-${TARGETARCH}" \
  && chmod +x /usr/local/bin/argo

# Argo Rollouts kubectl plugin
RUN curl -sLo /usr/local/bin/kubectl-argo-rollouts \
      "https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-${TARGETARCH}" \
  && chmod +x /usr/local/bin/kubectl-argo-rollouts

WORKDIR /workspace

CMD ["/bin/bash"]
