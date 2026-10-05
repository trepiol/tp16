
# TP16 — Escaneo de Seguridad de Contenedores, Dependencias e IaC con Trivy

## Objetivo y alcance

Trivy agrega controles SCA, de imagen de contenedor e IaC antes del despliegue. La aplicación objetivo es `devops-tp12/app/backend`; el pipeline conserva los workflows previos, incluido Semgrep (`.github/workflows/semgrep.yml`). El directorio `devops-TP06/` se mantiene como antecedente histórico y ya no se usa para construir la imagen TP16.

## Arquitectura y Render First

Se usa el chart real `devops-tp12/chart/`. `devops-tp12/values-prod.yaml` selecciona `tp16-postgres-credentials` como Secret externo y no contiene una contraseña. El chart conserva sus defaults de laboratorio; `createSecret: false` omite el Secret renderizado de producción. Antes del análisis IaC:

```bash
helm lint devops-tp12/chart -f devops-tp12/values-prod.yaml
helm template tp16 devops-tp12/chart -f devops-tp12/values-prod.yaml > manifests-rendered-prod.yaml
python3 -c 'import yaml; print(sum(d is not None for d in yaml.safe_load_all(open("manifests-rendered-prod.yaml"))))'
trivy config manifests-rendered-prod.yaml
```

No se analiza `chart/templates/` directamente: Helm debe resolver primero las plantillas Go. El manifiesto renderizado se conserva en el repositorio como evidencia reproducible de la auditoría y no incluye objetos Secret.

## SCA, Container Scan e IaC

```bash
bash scripts/preparar-trivy-sca.sh
trivy fs --scanners vuln --severity HIGH,CRITICAL .trivy-sca
trivy fs --scanners secret --severity HIGH,CRITICAL devops-tp12/app/backend
trivy fs --scanners vuln --format json --output trivy-fs-report.json .trivy-sca

docker build -t tp16-notes-backend:local devops-tp12/app/backend
trivy image --severity HIGH,CRITICAL tp16-notes-backend:local
trivy config manifests-rendered-prod.yaml
trivy config --misconfig-scanners terraform guia-11/
```

El inventario SCA combina requirements.txt y requirements-dev.txt en una ruta temporal porque Trivy reconoce requirements.txt, pero no descubre el archivo requirements-dev.txt directamente. El escaneo de secretos corre aparte sobre el backend fuente. El archivo temporal está excluido de Git. El escaneo de Terraform se ejecuta y se documenta con sus hallazgos. El alcance obligatorio de imagen en esta entrega es el backend. Como V2 conviene escanear también frontend y todas las imágenes efectivamente desplegadas.

## Pipeline, Andon Cord y artifacts

1. `build-and-package` construye una vez el backend TP12, lo guarda como tarball Docker con SHA-256 y publica un artifact con retención de un día.
2. `trivy-andon-cord` descarga y carga esa imagen, renderiza Helm y falla con exit code 1 ante HIGH/CRITICAL en SCA, imagen o YAML renderizado. Los reportes se adjuntan como artifacts cuando se generan.
3. `trivy-audit-report` analiza LOW/MEDIUM de forma informativa, exit code 0 y reportes JSON retenidos siete días.
4. `deploy-k8s-helm` sólo corre para `main`, depende de ambos jobs Trivy y reutiliza el mismo tarball. Requiere `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `KUBECONFIG_B64`, `POSTGRES_USER`, `POSTGRES_PASSWORD` y `POSTGRES_DB`. Sin Docker Hub o kubeconfig, no declara un despliegue exitoso; el resumen indica el paso omitido.

La Action de Trivy se fija a un commit SHA y a una versión concreta de Trivy para reducir el riesgo de supply chain. Las demás Actions existentes no se actualizaron por este TP.

## Lectura del exit code

- `0`: el comando terminó sin findings que cumplan el filtro de severidad aplicado; no significa ausencia absoluta de riesgo.
- `1`: se encontraron issues que cumplen el umbral bloqueante o falló un paso configurado como gate. Se debe revisar el detalle de Trivy, corregir la causa y volver a ejecutar.
- Los reportes LOW/MEDIUM son informativos y usan `exit-code 0`; requieren triage, pero no bloquean el build.

Una vulnerabilidad HIGH/CRITICAL en una dependencia transitiva o paquete del sistema puede existir aunque el código propio esté correcto. SCA, SAST (Semgrep), DAST (ZAP), escaneo de contenedor, IaC y observabilidad/runtime cubren riesgos distintos.

## Verificación local

```bash
bash scripts/verificar-trivy.sh
bash -n scripts/*.sh devops-tp12/scripts/*.sh
helm lint devops-tp12/chart -f devops-tp12/values-prod.yaml
helm template tp16 devops-tp12/chart -f devops-tp12/values-prod.yaml > manifests-rendered-prod.yaml
python3 -c 'import yaml; list(yaml.safe_load_all(open("manifests-rendered-prod.yaml")))'
yamllint -d relaxed .github/workflows/cicd.yml devops-tp12/values-prod.yaml
```

## Matriz de controles

| Fase / Job | Dominio | Severidades | Exit code | Acción | Evidencia |
|---|---|---|---|---|---|
| build-and-package | Build único | — | No aplica | Guarda la imagen etiquetada con `github.sha` | Artifact Docker, 1 día |
| trivy-andon-cord | SCA, imagen e IaC renderizado | HIGH, CRITICAL | 1 si hay findings | Bloquea las dependencias posteriores | Tablas de findings y YAML renderizado |
| trivy-audit-report | SCA, imagen e IaC renderizado | LOW, MEDIUM | 0 | Informa sin bloquear | Artifacts JSON, 7 días |
| deploy-k8s-helm | Publicación y despliegue | — | Fallo real de deploy; omisión explícita si faltan credenciales | Publica/despliega la imagen ya construida | Resumen del job |

V2: exigir los checks de estado mediante branch protection; fijar todas las Actions a SHA; mantener DB de Trivy cacheada; generar SBOM; hacer findings informativos accionables; versionar la imagen frontend; evaluar runner reproducible y agregar kube-state-metrics/autenticación instrumentada para completar las alertas TP12C.
