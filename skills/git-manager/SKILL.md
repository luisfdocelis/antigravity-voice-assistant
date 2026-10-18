---
name: "git-manager"
description: "Activar al realizar checkout de ramas, hacer commits, subir cambios al repositorio (push), gestionar fusiones (merge) o crear pull requests (PR)"
---

# Git Manager Skill — Antigravity Voice Assistant 🎙️

Esta Skill gestiona la nomenclatura semántica, el aislamiento de ramas y el proceso de publicación de Pull Requests (PR) en el proyecto **Antigravity Voice Assistant**.

## Reglas de Control de Flujo de Git

1. **Verificación Previa de Estado Limpio (`git status`):**
   Antes de crear o cambiar de rama, se debe verificar que no existan cambios pendientes o archivos no rastreados (`git status --porcelain`). Si los hay, se deben enviar a `stash` o realizar un commit parcial antes de proceder.

2. **Creación Automática de Ramas:**
   Para garantizar un repositorio limpio y seguir el flujo de desarrollo, la creación de ramas debe realizarse siempre a través de los scripts automáticos del repositorio desprendiéndose de `development`:
   - **Bash (Linux/macOS):**
     ```bash
     ./.agents/scripts/start-branch.sh <tipo> "<descripcion-corta>"
     ```
   - **PowerShell (Windows):**
     ```powershell
     .\.agents\scripts\start-branch.ps1 -Type <tipo> -Name "<descripcion-corta>"
     ```

   > [!IMPORTANT]
   > **Permisos de Ejecución en Entornos de Agente / Sandbox (`BypassSandbox: true`):**
   > Los comandos y scripts que alteran el repositorio Git (`start-branch.sh`, `pr-flow.sh`, `git checkout`, `git commit`, `git push`) requieren escribir en `.git/` y comunicarse con el remote vía red.
   > Dado que el entorno sandbox estándar de Antigravity monta el subdirectorio `.git/` en modo solo lectura (`ro`) y aísla la red, **el agente debe invocar estas operaciones con `BypassSandbox: true`** (o solicitar al usuario ejecutarlas en su terminal local). De lo contrario, Git fallará con `error: cannot open '.git/FETCH_HEAD': Read-only file system` o `cannot lock ref`.

3. **Nomenclatura Obligatoria de Ramas:**
   La rama creada debe utilizar estrictamente uno de los siguientes prefijos según la naturaleza del cambio:
   - `feat/nombre-feature` (Nuevos desarrollos / features)
   - `fix/nombre-bug` (Corrección de fallas / bugs)
   - `doc/nombre-doc` (Cambios exclusivos de documentación)
   - `test/nombre-test` (Añadir o corregir pruebas unitarias o de integración)
   - `refactor/nombre-refactor` (Mejoras o reestructuraciones de código interno)
   - `chore/nombre-mantenimiento` (Mantenimiento de dependencias, scripts o configuraciones)
   - `release/nombre-release` (Cortes de versión y releases)
   - `patch/nombre-patch` (Parches y correcciones de bajo impacto)
   - `hotfix/nombre-hotfix` (Correcciones urgentes de producción)
   - `perf/nombre-perf` (Mejoras específicas de rendimiento)
   - `ci/nombre-ci` (Cambios en pipelines e integración continua)
   - `build/nombre-build` (Ajustes del sistema de build o tooling)
   - `sec/nombre-sec` (Hardening o correcciones de seguridad)
   - `deps/nombre-deps` (Actualizaciones o gestión de dependencias)
   - `revert/nombre-revert` (Reversión explícita de commits anteriores)

4. **Sincronización y Resolución de Conflictos (Rebase):**
   Si la rama `development` ha recibido nuevos cambios durante el desarrollo, la rama activa debe actualizarse mediante `rebase` o `merge` antes de enviar el PR:
   ```bash
   git fetch origin development
   git rebase origin/development
   ```

5. **Restricción de Push Directo:**
   - Queda estrictamente prohibido realizar pushes directos a las ramas `master`, `development` o `main` con cambios de código funcional o de configuración del sistema.
   - Todo cambio de código debe realizarse en su rama correspondiente y proponerse mediante un Pull Request (PR) en GitHub.

6. **Mensajes de Commit Semánticos:**
   Los commits deben ser descriptivos y seguir el estándar de *Conventional Commits* (ej. `feat(auth): add jwt token validation`).

---

### Pull Requests (PRs) y Flujo de Fusión

Cuando se finalice la verificación local y el desarrollo en la rama, la publicación del Pull Request debe realizarse mediante el flujo automático:
- **Bash (Linux/macOS):**
  ```bash
  ./.agents/scripts/pr-flow.sh "<titulo-pr>" "<descripcion-pr>"
  ```
- **PowerShell (Windows):**
  ```powershell
  .\.agents\scripts\pr-flow.ps1 -Title "<titulo-pr>" -Body "<descripcion-pr>"
  ```

#### Criterios y Estructura del Pull Request:
- **Título del PR:** Debe seguir el formato `prefijo(scope): breve descripcion` (ej. `feat(auth): add jwt token validation`).
- **Commits atómicos previos al Push:**
  - Consolidar el cambio de cada repositorio en commits atómicos antes del push.
  - La documentación técnica y guías viven directamente en el repositorio (`README.md`, `rules/`, `skills/`).
  - ⚠️ Evitar pushes fraccionados a la misma rama una vez iniciada la integración continua.
- **Cuerpo del PR:** Debe incluir la siguiente información estructurada:
  - **What:** Descripción concisa de los cambios realizados.
  - **Why:** Explicación del problema o el objetivo que resuelve el PR.
  - **How:** Resumen técnico de la solución y las tecnologías/módulos modificados.
  - **Documentation & Walkthrough:** Enlaces a los documentos generados en `docs/plans/` (ej. `walkthrough.md`, `analysis.md`).
  - **Breaking changes:** Declaración de cambios que rompan la compatibilidad (si aplica).

#### Monitoreo y Fusión:
- El script de flujo del PR (`pr-flow`) o `gh pr checks --watch` / `gh run watch` debe monitorear el estado completo de los workflows.
- **Validación Fidedigna de Checks:**
  - Se debe verificar que el workflow principal de compilación y pruebas (`CI - Build & Test`) haya concluido completamente con `conclusion: success`.
  - ⚠️ **PROHIBIDO asumir éxito basándose únicamente en el workflow rápido de documentación (`Docs`)**.
  - Si los checks fallan (estado rojo), se debe detener el proceso, informar los logs de error al usuario y regresar a la fase de corrección de código local.
  - Si todos los checks pasan correctamente (estado verde), se activará el protocolo de pausa.

#### ⚠️ PROTOCOLO OBLIGATORIO DE PAUSA Y CONFIRMACIÓN EXPLÍCITA DE MERGE
Cuando todos los checks de GitHub Actions estén en **verde**:
1. El agente **NUNCA** responderá automáticamente el prompt interactivo de la CLI ni ejecutará el merge sin consultar.
2. El agente **DEBE PAUSAR** e informar al usuario que los checks han pasado con éxito.
3. El agente **DEBE SOLICITAR CONFIRMACIÓN EXPLÍCITA** al usuario presentando las opciones de fusión (ej. **Squash Merge (Recomendado)**, **Rebase** o **Merge commit**).
4. Únicamente tras recibir la aprobación afirmativa del usuario, el agente enviará la entrada correspondiente para ejecutar la fusión del PR.

#### Secuencia Post-Merge (Limpieza Local):
Una vez confirmado y completado el merge del PR en GitHub:
1. El agente retornará a `development` y actualizará el repositorio local:
   ```bash
   git checkout development
   git pull origin development
   ```
2. Eliminar la rama local que ya fue fusionada:
   ```bash
   git branch -d <nombre-rama-fusionada>
   ```
3. Confirmar al usuario que la rama fue fusionada y la base de desarrollo `development` está sincronizada.
