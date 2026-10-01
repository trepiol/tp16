#!/usr/bin/env bash
set -uo pipefail
errors=0
ok() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1"; errors=$((errors + 1)); }
if command -v trivy >/dev/null 2>&1; then ok "Trivy $(trivy --version | head -n1)"; else fail 'Trivy no instalado'; fi
for f in .github/workflows/cicd.yml devops-tp12/values-prod.yaml devops-tp12/monitoring-k8s-manifests.yaml manifests-rendered-prod.yaml; do [[ -f "$f" ]] && ok "$f" || fail "Falta $f"; done
for job in build-and-package trivy-andon-cord trivy-audit-report deploy-k8s-helm; do grep -q "^  ${job}:" .github/workflows/cicd.yml && ok "Job $job" || fail "Falta job $job"; done
grep -q 'helm template' .github/workflows/cicd.yml && ok 'Render First configurado' || fail 'Falta helm template'
grep -q 'manifests-rendered-prod.yaml' .github/workflows/cicd.yml && ok 'YAML renderizado integrado' || fail 'Falta manifiesto renderizado'
bash -n devops-tp12/scripts/generar-alertas-seguridad.sh scripts/preparar-trivy-sca.sh || fail 'Error de sintaxis en script auxiliar'
grep -q 'preparar-trivy-sca.sh' .github/workflows/cicd.yml && ok 'SCA incluye dependencias de producción y desarrollo' || fail 'Falta preparar inventario SCA combinado'
if [[ $errors -eq 0 ]]; then echo 'Verificación TP16 satisfactoria.'; exit 0; fi
printf 'Verificación TP16: %s requisito(s) faltante(s).\n' "$errors"; exit 1
