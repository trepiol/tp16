# TP16 — Informe base

> Evidencia del TP16 ejecutado en la VM. Cada sección está separada para poder iniciar en una página al exportar a PDF.

<div style="page-break-after: always"></div>

## 1. Pasos solicitados en la guía

- Usuario: `alumno`; hostname: `debian`; repositorio: `/home/alumno/tp16`; rama inicial: `main`.
- Prompt observado: `alumno@debian:~/tp16$`.
- Comandos de auditoría: `pwd`, `whoami`, `hostname`, `git status --short --branch`, `git branch --show-current`, `git remote -v`, `git log -5 --oneline`.
- Render: `helm lint devops-tp12/chart -f devops-tp12/values-prod.yaml`; `helm template tp16 devops-tp12/chart -f devops-tp12/values-prod.yaml > manifests-rendered-prod.yaml`.
- Validación: `kubectl apply --dry-run=client -f manifests-rendered-prod.yaml`; los 10 objetos se aceptaron en dry-run.
- Trivy: `bash scripts/preparar-trivy-sca.sh` prepara SCA combinado; también se escanearon imagen backend, YAML renderizado, secretos backend y Terraform.
- Trivy 0.74.0; DB actualizada 2026-09-30. Instalación Aqua validada; apt update global encontró firma faltante en repo HashiCorp, por lo que se aisló el repo Trivy.
- helm lint pasó (aviso informativo: icono recomendado); Helm produjo 10 objetos/documentos YAML válidos sin Secret. Flake8 pasó; pytest 7/7, cobertura 90%.

<div style="page-break-after: always"></div>

## 2. Usuario Git involucrado

- `git config --get user.name`: `trepiol`.
- `git config --get user.email`: `ezequiel.cuya@estudiantes.unahur.edu.ar`.
- `git log`: HEAD inicial `f5ce345 Agregar Semgrep SAST al pipeline`; antecedente `dd6b585 inicio`.
- Los cambios se organizan en commits locales pequeños; la secuencia se informa con git log --oneline --decorate -10. No se empujaron porque el Andon detecta findings HIGH/CRITICAL.

<div style="page-break-after: always"></div>

## 3. Desviaciones respecto del enunciado

- Las rutas `devops-portfolio/` del profesor no existen como carpeta raíz; el chart real es `devops-tp12/chart/`.
- El ejemplo del pipeline construye `devops-TP06/backend`; la imagen TP16 sale de `devops-tp12/app/backend/`.
- TP10B y TP12C se integraron como mejoras sobre los recursos existentes, no se recrearon.
- La métrica propuesta para login no existe porque la API no implementa autenticación. La alerta de reinicios requiere kube-state-metrics no scrapeado.
- La configuración de producción referencia un Secret Kubernetes externo. No almacena contraseñas en Git ni en el manifiesto renderizado.
- Trivy 0.74.0; aquasecurity/trivy-action fijada a SHA a9c7b0f06e461e9d4b4d1711f154ee024b8d7ab8.
- apt update global encontró un repositorio HashiCorp preexistente sin firma válida; Trivy se instaló usando sólo el origen oficial Aqua.
- SCA, imagen e IaC bloquean HIGH/CRITICAL según el enunciado TP16; el job LOW/MEDIUM se ejecuta con if: always para dejar evidencia aunque el Andon falle.
- Problema real: el repositorio APT HashiCorp preexistente no tenía firma válida; no se modificó ese origen y se aisló la instalación desde el repositorio oficial de Aqua.

<div style="page-break-after: always"></div>

## 4. Versión 2

1. Fijar cada GitHub Action a un commit SHA revisado, no sólo tags.
2. Pinning y verificación de versión/checksum de Trivy, Helm, Python y base images.
3. Escanear frontend y toda imagen realmente desplegada.
4. Configurar required status checks y branch protection: un job rojo sin política de rama no impide por sí solo el merge.
5. Mantener credenciales como GitHub Secrets/OIDC o gestor externo y cifrar Secret de Kubernetes en reposo.
6. Cachear la DB de Trivy con invalidación y permisos mínimos.
7. Publicar SBOM (SPDX o CycloneDX) junto con la imagen.
8. Separar findings bloqueantes de informativos y acordar SLA para remediación.
9. Elegir runners reproducibles y parcheados en vez de depender indefinidamente de `ubuntu-latest`.
10. Completar métricas de auth e instalar kube-state-metrics antes de activar las alertas respectivas.

<div style="page-break-after: always"></div>

## 5. Interpretación de un mensaje

- Mensaje observado: CVE-2024-1135 para gunicorn 21.2.0, severidad HIGH; Trivy informa versión corregida 22.0.0.
- La vulnerabilidad afecta el servidor WSGI incluido en el backend. También aparece CVE-2024-6827 para esa versión.
- El escaneo de requirements detecta además CVE-2024-6221 en flask-cors 4.0.0. La imagen reconstruida encontró 50 HIGH Debian más 3 HIGH Python; su gate devolvió exit code 1. El gate SCA combinado y el gate IaC también devolvieron exit code 1. El escaneo de secretos del backend reportó 0 findings.
- No se actualizaron paquetes ni se remedió ningún finding; el escaneo no se usó para afirmar remediación.
- Si Trivy devuelve exit code 1, el gate encontró una issue que cumple el umbral; no equivale a que el análisis haya fallado técnicamente.

<div style="page-break-after: always"></div>

## 6. Novedades o sorpresas

- SCA detecta riesgo en dependencias transitivas aunque el código propio pase SAST.
- Una imagen puede contener CVEs de su sistema base y librerías incluidas.
- Trivy config evalúa IaC y manifiestos Kubernetes; Helm crudo no es YAML final.
- Build-once y artifact SHA permiten analizar y reutilizar exactamente la misma imagen entre jobs.
- El Andon Cord sólo frena merges cuando GitHub exige su check de estado.
- El escaneo predeploy no sustituye DAST ni controles runtime/observabilidad.
- Resultado: SCA producción 3 HIGH/4 MEDIUM/1 LOW; SCA combinado con requirements-dev 3 HIGH/5 MEDIUM/1 LOW; secretos backend 0; imagen Debian 50 HIGH/84 MEDIUM/66 LOW/4 UNKNOWN y Python 3 HIGH/9 MEDIUM/2 LOW; IaC renderizado 11 HIGH/14 MEDIUM/28 LOW; Terraform 0. Imagen e IaC bloquean el deploy dependiente.

<div style="page-break-after: always"></div>

## 7. Conclusión

TP16 extiende DevSecOps y Shift Left con SCA, Container Security e IaC Security dentro de CI/CD y Supply Chain Security mediante artefactos identificados por SHA. Se complementa con SAST de Semgrep, DAST de ZAP y observabilidad/runtime de Prometheus/Grafana. Los escáneres reducen riesgo antes del despliegue, pero no reemplazan el monitoreo, respuesta a incidentes, actualización continua ni controles de acceso en ejecución.

Estado: integración y validaciones locales realizadas. Sin workflow remoto, PR o despliegue: gh no está autenticado y no hay secrets/contexto publicados en Actions. Findings quedan deliberadamente sin remediar; el Andon refleja el baseline. No se agregó vulnerabilidad de prueba porque el baseline ya es rojo.
