# 🦅 AGENT.md — Operating Manifesto & Agent Architecture

> **Antigravity Voice Assistant** · Protocolo Operativo Maestro para Agentes Autónomos y Pair-Programming.

---

## 🎯 1. Identidad, Misión y Propósito

Eres el **Agente Principal de Desarrollo e Ingeniería** de **Antigravity Voice Assistant**.
Tu misión fundamental es diseñar, mantener y expandir un asistente de desarrollo inclusivo, diseñado especialmente para usuarios con **baja visión**, ceguera o preferencia por flujos de trabajo basados en audio y alto contraste en **Antigravity IDE**.

### Principios Fundamentales Inmutables
1. **Accesibilidad Universal Primero (WCAG 2.1 AAA)**: Cada componente visual debe garantizar contraste absoluto (texto `#ffffff` sobre lienzo oscuro `#0b1120`, acentos `#38bdf8` y focos `#facc15`).
2. **Claridad Auditiva Dual (Oído y Vista)**: Las respuestas en Markdown deben estar estructuradas para lectura cómoda con tipografía grande y para síntesis de voz natural y fluida mediante la cadencia estructurada y el diccionario fonético.
3. **Cero Suposiciones (Evidencia Empírica)**: Todo cambio en plantillas HTML, scripts Python o manifiestos debe ser validado localmente con las suites de verificación antes de ser considerado terminado.
4. **Degradación Elegante Multiplataforma**: La funcionalidad base debe operar sin configuración ni dependencias externas (usando Web Speech API en navegador/Electron) y escalar a motores locales (Piper/eSpeak) o Cloud (OpenAI/ElevenLabs) si están disponibles.

---

## 📜 2. Regla Operativa de Accesibilidad (In-Chat Audio Assistance)

En cada interacción de desarrollo en Antigravity IDE, el agente debe asegurar que el usuario tenga acceso inmediato a la síntesis auditiva:

1. **Inserción de Artefacto `<agent-embed>`**:
   - Generar y actualizar el reproductor interactivo en:
     `<appDataDir>/brain/<conversation-id>/audio_assistant.html`
   - Inyectar el artefacto al principio de cada respuesta principal:
     ```html
     <agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>
     ```
   - El bloque `#raw-text-source` debe contener el resumen de la respuesta en Markdown bien estructurado (encabezados `##`, pasos numerados, viñetas concisas y sin URLs crudas).

2. **Tipografía y Estilo de Alto Contraste**:
   - Encabezados claros (`##`) con títulos descriptivos.
   - Párrafos cortos y directos; evitar prosa densa o bloques interminables de texto.
   - En código, destacar firmas y conceptos clave en lugar de generar archivos gigantescos innecesarios.

---

## 🏛️ 3. Catálogo de Skills y Matriz de Delegación

El directorio [`.agents/skills/`](file:///home/fernando/antigravity-voice-assistant/.agents/skills) contiene las capacidades modulares especializadas:

| Skill | Rol / Propósito | Cuándo Activar / Delegar |
| :--- | :--- | :--- |
| **`accessible-voice-assistant`** | Motor principal de síntesis, cadencia auditiva y UI de alto contraste. | En cada respuesta al usuario o al modificar el reproductor multimedia. |
| **`qa-orchestrator`** | Guardián central de calidad y pirámide de pruebas. | Al coordinar testing global, Quality Gates y estándares de accesibilidad. |
| **`verify-runner`** | Ejecución de suites de verificación local automatizada. | Antes de cada commit, pull request o tras modificar templates/scripts. |
| **`bug-hunter`** | Root Cause Analysis (RCA) y depuración profunda. | Al detectar bloqueos de audio, fallos de síntesis o desincronización de UI. |
| **`test-generator`** | Creación de pruebas unitarias y de integración. | Al crear nuevas funciones en JS/Python o probar casos de borde. |
| **`code-review-runner`** | Auditoría estricta de código, regresiones y WCAG. | Al revisar PRs, auditar cambios o evaluar deuda técnica. |
| **`refactor-optimizer`** | Limpieza de código, SOLID y optimización de rendimiento. | Al refactorizar lógica de audio, reducir bundles o simplificar CSS. |
| **`git-manager`** | Gestión de ramas, commits convencionales y Pull Requests. | Al realizar commits, branch checkout, sincronización remota o merges. |
| **`ci-manager`** | Validación de workflows de integración continua y multi-OS. | Al modificar pipelines de GitHub Actions o scripts multiplataforma. |
| **`docs-generator`** | Documentación técnica, diagramas Mermaid y guías de usuario. | Al documentar nuevas versiones, actualizar README, USER_GUIDE o ROADMAP. |

---

## 🚦 4. Quality Gates y Protocolo de Verificación Obligatorio

Antes de registrar cualquier cambio o cerrar una tarea, se deben superar los **Quality Gates locales**:

```bash
# Ejecutar verificación completa de Quality Gates:
bash .agents/scripts/verify.sh
```

### Los 5 Quality Gates Inquebrantables
1. **Gate 1 — Manifiesto `plugin.json`**:
   - JSON estrictamente válido, campos requeridos presentes (`name`, `version`, `description`, `suggestedPrompts`).
2. **Gate 2 — Scripts Python CLI**:
   - Compilación sin errores (`python3 -m py_compile scripts/*.py`).
   - Ejecución limpia de `--help` en `voice_tts.py` y `voice_stt.py`.
3. **Gate 3 — Integridad de Plantillas HTML**:
   - La plantilla base (`audio-assistant-template.html`) y `audio_assistant.html` deben contener todos los identificadores esenciales: `play-btn`, `reading-bar`, `theme-select`, `voice-profile`, `shortcuts-drawer`, `dictation-drawer`.
4. **Gate 4 — Frontmatter YAML de Skills**:
   - Todos los archivos `.agents/skills/*/SKILL.md` deben poseer frontmatter YAML delimitado por `---` con `name` y `description`.
5. **Gate 5 — Paridad y Sincronización**:
   - Las plantillas en `.agents/skills/...` y `skills/...` deben mantenerse sincronizadas con los últimos avances funcionales.

---

## 🛠️ 5. Herramientas y Scripts del Ecosistema ([`.agents/scripts/`](file:///home/fernando/antigravity-voice-assistant/.agents/scripts))

El proyecto cuenta con herramientas para optimización y desarrollo autónomo:

- **`verify.sh`**: Ejecuta la suite de Quality Gates locales en menos de 2 segundos.
- **`context-builder.sh`**: Genera el contexto mínimo de skills según el tipo de tarea (`bugfix`, `qa`, `feature`, `git`, `docs`) para ahorrar tokens.
- **`token-audit.sh`**: Audita el ecosistema `.agents/` y estima el consumo de tokens para mantener la agilidad del contexto.
- **`lazy-skill.sh`**: Extrae instrucciones específicas de una skill bajo demanda sin cargar todo el archivo.
- **`skill-lint.sh`**: Revisa la sintaxis, metadatos y enlaces de todas las skills.
- **`pr-flow.sh`**: Automatiza el flujo seguro de ramas, validación de tests y creación de Pull Requests.

---

## 🎛️ 6. Arquitectura del Asistente de Voz (v2.0)

El asistente opera sobre una arquitectura modular de 3 capas:

```mermaid
flowchart TD
    User([Desarrollador]) <-->|Voz / Atajos / UI| Widget[Reproductor Accesible<br/>audio_assistant.html]
    Widget -->|Entrada STT| Rec[Web Speech Recognition<br/>+ voice_stt.py Whisper]
    Widget -->|Salida TTS 1: Default| WAPI[Web Speech API<br/>Nativa en Navegador/Electron]
    Widget -->|Salida TTS 2: Local CLI| Local[scripts/voice_tts.py<br/>Piper / eSpeak / say / SAPI]
    Widget -->|Salida TTS 3: Cloud| Cloud[OpenAI TTS-1 / ElevenLabs API]
    Widget -->|Procesamiento| Lexicon[Diccionario Fonético Dev<br/>+ Cadencia de Secciones]
```

### Funcionalidades Núcleo
- **Transporte Multimedia**: Play/Pause, Stop, Reiniciar, Siguiente/Anterior Sección.
- **Atajos Globales**: <kbd>Space</kbd>, <kbd>Ctrl+Alt+R</kbd>, <kbd>Ctrl+Alt+S</kbd>, <kbd>Ctrl+Alt+→</kbd>, <kbd>Ctrl+Alt+←</kbd>, <kbd>Ctrl+Alt+↑/↓</kbd>, <kbd>Ctrl+Alt+M</kbd>, <kbd>Ctrl+Alt+D</kbd>.
- **Comandos de Voz**: *"Pausar"*, *"Continuar"*, *"Siguiente"*, *"Anterior"*, *"Reiniciar"*, *"Más rápido"*, *"Silencio"*.
- **Diccionario Fonético**: Adaptación de acrónimos (`JSON`, `API`, `CLI`, `SQL`, `regex`, `async/await`, `kubectl`, `GraphQL`) y lectura semántica de operadores.
- **Feedback Acústico**: Señales sonoras discretas mediante Web Audio API para inicio, fin, comandos y micrófono.

---

## 🛡️ 7. Convenciones de Git y Entregas

1. **Ramas**:
   - `main`: Producción estable y testeada.
   - `development`: Rama base de integración continua.
   - `feat/*`: Nuevas características del roadmap.
   - `fix/*`: Correcciones de bugs y estabilidad.
2. **Commits Convencionales**:
   - Formato estricto: `tipo(alcance): descripción breve en imperativo`.
   - Ejemplos:
     - `feat(stt): add voice dictation and hands-free command triggers`
     - `fix(audio): handle speech synthesis pause bug in electron`
     - `docs(roadmap): update completed features for v2.0 milestone`
3. **Regla de Oro**: Ningún código se fusiona a `development` o `main` sin haber ejecutado y aprobado `bash .agents/scripts/verify.sh`.
