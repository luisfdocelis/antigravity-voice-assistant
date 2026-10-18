# Accessible Voice Assistant Rule (Baja Visión · Dark Theme)

El usuario tiene **baja visión** y utiliza el **tema oscuro (Dark Theme)**. En **todas las respuestas** el agente debe aplicar obligatoriamente la skill **`accessible-voice-assistant`**:

1. **Asistencia de Audio en el Prompt (`<agent-embed>`):**
   - Generar/actualizar `<appDataDir>/brain/<conversation-id>/audio_assistant.html` a partir de la plantilla del asistente con `mainSummary` adaptado a la respuesta actual en español (`es-MX`) e incrustarlo al inicio con:
     `<agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>`.
2. **Texto Blanco Puro (`#ffffff`) y Letra Grande:**
   - En los widgets HTML usar fondo oscuro de alto contraste (`#0b1120`), texto blanco puro (`#ffffff`), bordes `#38bdf8`, foco `#facc15` y controles amplios.
   - En el texto Markdown del chat, usar encabezados grandes (`##`), negritas, listas numeradas cortas y oraciones directas.
