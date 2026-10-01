# Auditoría e implementación TP16

## Auditoría previa

- VM: Debian 13, kernel Linux 6.12.101+deb13-amd64; usuario `alumno`, hostname `debian`.
- Raíz: `/home/alumno/tp16`; rama `main`; árbol inicial limpio (`## main...origin/main`).
- Remoto: `git@github-tp16:trepiol/tp16.git`; HEAD inicial `f5ce345` (Semgrep SAST) y antecedente `dd6b585`.
- Identidad Git: `trepiol`, `ezequiel.cuya@estudiantes.unahur.edu.ar`.
- Estructura confirmada: backend y frontend integrados en `devops-tp12/app/`; chart Helm en `devops-tp12/chart/`; values local y manifiestos de monitoreo en `devops-tp12/`; Terraform en `guia-11/`; workflows `cicd.yml`, `pr-check.yml`, `semgrep.yml`.
- Herramientas detectadas antes de instalar Trivy: Helm 3.18.4, Docker 29.7.2, kubectl con contexto `k3d-notes-cluster`, Python 3 + PyYAML, yamllint, Terraform y GitHub CLI.
- `cicd.yml` anterior ejecutaba controles históricos TP06 y publicaba `devops-TP06/backend`; no representaba la aplicación integrada. `semgrep.yml` ya escaneaba TP12.

## TP10B integrado

- Ruta real: `devops-tp12/chart/`, no `devops-portfolio/`.
- Perfil nuevo: `devops-tp12/values-prod.yaml`. No replica los defaults locales; usa Secret externo `tp16-postgres-credentials` y evita renderizar credenciales.
- Render: `helm template tp16 devops-tp12/chart -f devops-tp12/values-prod.yaml > manifests-rendered-prod.yaml`.
- Se mantiene el patrón Render First; Trivy config analiza el YAML generado y no las plantillas Go.
- Comando original TP10B apuntaba a `~/devops-TP10`, `./devops-portfolio`, `values-prod.yaml` en otra ruta y una validación kubectl local. Adaptación: ejecutar desde raíz de `/home/alumno/tp16`, apuntar al chart existente y validar `manifests-rendered-prod.yaml`.

## TP12C integrado y límites de métricas

La aplicación exporta `app_requests_total{method,endpoint,status}` y `app_db_errors_total`. El stack existente ya contiene Prometheus, Grafana y alertas base AppDown, HighCPU, HighErrorRate y DiskSpaceLow. Se agregan las reglas adaptables para errores HTTP y errores de DB. La señal HTTP mide métricas de la API, no del Ingress, así que su nombre TP12C se conserva por trazabilidad y la descripción aclara la fuente real.

`PodReiniciosFrecuentesSeguridad` requiere `kube-state-metrics`, que no se encontró en el scrape config actual. `InvasionIntentosAuthFallidos` no puede activarse correctamente: el backend actual no tiene login ni emite una métrica de fallos de autenticación. No se inventaron métricas; queda documentado el trabajo de instrumentación.

## Desviaciones conscientes

- `devops-portfolio/` del enunciado es el nombre legado del chart (`Chart.yaml`), no un directorio de la raíz.
- El backend TP06 sigue en la historia del repo, pero el build TP16 usa `devops-tp12/app/backend/Dockerfile`.
- TP10B y TP12C se integran como incrementos al chart/ConfigMap existentes; no se recrean sus stacks.
- `cicd.yml` se reestructura. `pr-check.yml` y `semgrep.yml` se preservan.
- La Action `aquasecurity/trivy-action` se fija a SHA completa `a9c7b0f06e461e9d4b4d1711f154ee024b8d7ab8`; la versión del scanner se controla en `TRIVY_VERSION`.
- No se usarán credenciales Docker Hub o kubeconfig ficticias. El workflow anota claramente cualquier etapa omitida por falta de secrets.

## Registro local de escaneos

- Trivy 0.74.0; base DB v2 actualizada 2026-09-30. Instalación desde repositorio oficial Aqua; apt update general reportó firma faltante en repositorio HashiCorp preexistente, así que se usó origen oficial Trivy de forma aislada.
- SCA requirements.txt: 3 HIGH, 4 MEDIUM, 1 LOW. HIGH: flask-cors 4.0.0 (CVE-2024-6221, fix 4.0.2) y gunicorn 21.2.0 (CVE-2024-1135 y CVE-2024-6827, fix 22.0.0). No se actualizaron dependencias. El workflow escanea el inventario combinado para incluir dependencias de test y desarrollo.
- Imagen original tp16-notes-backend:local: Debian 13.7, 50 HIGH, 84 MEDIUM, 66 LOW y 4 UNKNOWN; Python 3 HIGH, 9 MEDIUM, 2 LOW. La imagen original ya no existe para repetir el scan; se conserva JSON en /tmp/tp16-image-before.json fuera del repo.
- IaC en manifests-rendered-prod.yaml: 11 HIGH, 14 MEDIUM, 28 LOW. HIGH incluye KSV-0014 (filesystem raíz no read-only) y KSV-0118 (security context por defecto). Sin remediación.
- Terraform: comando trivy config --misconfig-scanners terraform guia-11/; 0 findings. El filtro explícito limita la auditoría a Terraform.
- helm lint y helm template finalizaron correctamente; YAML con 10 objetos/documentos y sin Secret de credenciales. Flake8 pasó y pytest terminó con 7/7 pruebas, 90% cobertura.
- Andon bloquea HIGH/CRITICAL en SCA, imagen e IaC (exit-code 1), según TP16; el job LOW/MEDIUM es informativo y usa if: always para generar evidencia aunque Andon falle. El baseline tiene HIGH, por lo que el deploy dependiente no se ejecutará.
- No se ejecutó Actions ni se creó PR: gh no está autenticado y no hay secrets/contexto para deploy. No se hizo PR controlada porque el baseline real ya tiene HIGH y el usuario pidió no introducir ni remediar vulnerabilidades.
