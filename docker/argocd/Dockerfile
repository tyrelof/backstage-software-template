FROM alpine:3.20
ARG ARGOCD_VERSION=v2.11.7
RUN apk add --no-cache git curl bash grep ca-certificates \
 && curl -sSfL "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" -o /usr/local/bin/argocd \
 && chmod +x /usr/local/bin/argocd
# yq static (fast, no apk)
RUN curl -sSfL "https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64" -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq