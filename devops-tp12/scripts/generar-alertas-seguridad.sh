#!/usr/bin/env bash
set -euo pipefail
CONTEXT="${KUBE_CONTEXT:-k3d-notes-cluster}"
HOST="${INGRESS_HOST:-devops-portfolio.local}"
URL="${LAB_URL:-https://${HOST}:18443}"
for bin in kubectl curl; do command -v "$bin" >/dev/null || { echo "Falta $bin" >&2; exit 2; }; done
kubectl config get-contexts "$CONTEXT" >/dev/null 2>&1 || { echo "No existe $CONTEXT; no se genera tráfico." >&2; exit 2; }
[[ "$(kubectl config current-context)" == "$CONTEXT" ]] || { echo "Contexto diferente de $CONTEXT; no se genera tráfico." >&2; exit 2; }
kubectl get ingress -n devops-portfolio >/dev/null 2>&1 || { echo "No se encuentra el Ingress local." >&2; exit 2; }
echo "Sólo laboratorio local: $URL"
for path in /tp16-probe-not-found-{1..3}; do curl --silent --output /dev/null --max-time 5 --insecure -H "Host: $HOST" "$URL$path" || true; done
echo "Solicitudes locales completadas; no se simula autenticación inexistente."
