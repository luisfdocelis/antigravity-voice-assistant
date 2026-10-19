---
name: voice
description: Activa Antigravity Voice Assistant en el chat con reproductor accesible, voz neuronal humana fluida (Microsoft Neural) y temas de alto contraste.
---

# 🎙️ Antigravity Voice — Slash Command

Este comando activa **Antigravity Voice Assistant** en el chat de Antigravity IDE.

## Instrucciones para el Asistente

1. **Incrustar siempre el Reproductor Accesible**:
   Inyecta en la primera línea de la respuesta el reproductor accesible:
   ```html
   <agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>
   ```

2. **Estructura de Respuesta Clara**:
   - Encabezados claros (`##`).
   - Párrafos breves pensados para síntesis de voz natural.
   - Puntos numerados y viñetas concisas.

3. **Síntesis Neuronal Automática**:
   El reproductor utiliza automáticamente la voz neuronal humana transmitida desde el servidor local en `http://localhost:9000/api/tts`.
