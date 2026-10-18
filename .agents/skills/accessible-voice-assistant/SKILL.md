---
name: "accessible-voice-assistant"
description: "Asistencia de voz en español, texto blanco (#ffffff) y letra grande para baja visión en tema oscuro."
---

# Accessible Voice Assistant Skill — CrowKit 🦅

Esta Skill proporciona asistencia de audio en español (Text-to-Speech mediante Web Speech API), barra y botones de volumen (`0%` a `100%`), selector de tipos y timbres de voz (`Natural`, `Grave / Profunda`, `Clara / Aguda`, `Pausada y Cálida` + voces nativas del sistema), controles dinámicos de tamaño de fuente (`🔍 A-` / `🔍 A+` de `16px` a `42px`) y formato visual de alto contraste (texto blanco puro `#ffffff` sobre superficies oscuras `#0b1120`) para usuarios con baja visión en tema oscuro.

---

## 📌 Reglas de Formato Accesible en el Chat

1. **Tipografía Grande y Jerárquica:**
   - Utilizar encabezados `##` para las ideas principales y opciones de decisión, de modo que el cliente de chat renderice una fuente de mayor tamaño y grosor.
   - Evitar bloques largos de texto continuo o tablas con muchas columnas; preferir listas numeradas cortas y directas.
2. **Alto Contraste en Tema Oscuro:**
   - En todos los artefactos HTML o widgets inline (`<agent-embed>`), utilizar **texto blanco puro (`#ffffff`)** sobre fondo oscuro (`#0b1120` / `#111827`) con bordes cian (`#38bdf8`) y anillos de foco amarillos (`#facc15`).
   - Mantener tamaños de fuente base de **`24px`** y permitir ajuste interactivo entre `16px` y `42px`.

---

## 🔊 Flujo para Insertar el Reproductor de Voz en el Chat

1. **Copiar y Actualizar la Plantilla Base:**
   Tomar como referencia el archivo [resources/audio-assistant-template.html](resources/audio-assistant-template.html) y guardarlo en el directorio de artefactos de la conversación (`<appDataDir>/brain/<conversation-id>/audio_assistant.html`) con `UserFacing: true`.
2. **Personalizar el Guion de Voz y Lectura (`mainSummary`):**
   Actualizar la constante `mainSummary` dentro del `<script>` con el resumen hablado y visual de la respuesta actual en español (`es-MX` / `es`). El widget muestra ese mismo texto en blanco puro dentro de su recuadro de lectura escalable.
3. **Incrustar el Widget en la Respuesta:**
   Incluir la etiqueta `<agent-embed>` al inicio de la respuesta del chat:

```html
<agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>
```

---

## ⌨️ Controles Accesibles Incluidos en la Plantilla

- **▶️ Escuchar / ⏯️ Pausar / ⏹️ Detener:** Barra superior compacta con los controles principales de locución.
- **📄 Texto Colapsable (`#btn-text` / `#summary-display`):** Botón desplegable (`📄 Texto ▾`) que muestra u oculta el recuadro de texto del resumen (colapsado por defecto para ahorrar espacio, persistido en `localStorage`).
- **⚙️ Ajustes Colapsables (`#btn-settings` / `#settings-drawer`):** Botón desplegable (`⚙️ Ajustes ▾`) que mantiene la interfaz limpia y compacta, abriendo o cerrando bajo demanda el panel con:
  - **🎨 Tema DaisyUI (`#theme-select`):** Selector con 9 paletas oficiales de DaisyUI adaptadas a alto contraste (`night`, `dracula`, `synthwave`, `luxury`, `forest`, `aqua`, `cyberpunk`, `coffee`, `emerald`), persistido en `localStorage`.
  - **🔘 Botones (`#btn-mode-select`):** Permite elegir entre `Iconos + Texto`, `Solo Iconos` o `Solo Texto` en los botones del reproductor (persistido en `localStorage`).
  - **📐 Tamaño Widget (`#scale-slider`, `75%` a `150%`):** Barra deslizante y botones (`➖` / `➕`) que redimensionan proporcionalmente todo el widget del asistente entre `75%` y `150%` (persistido en `localStorage`).
  - **💧 Opacidad / Transparencia (`#opacity-slider`, `25%` a `100%`):** Barra deslizante y botones (`➖` / `➕`) que ajustan la opacidad del fondo del widget manteniendo el texto 100% nítido (persistido en `localStorage`).
  - **🔍 Letra (`A-` / `A+`):** Ajusta en tiempo real el tamaño de la fuente (`16px` a `42px`, persistido en `localStorage`).
  - **🔊 Volumen (`🔉 -`, barra deslizante y `🔊 +`):** Ajusta el volumen de `0%` a `100%` en pasos de `10%` o continuo.
  - **⚡ Velocidad y 🎙️ Tipo de Voz:** Selector de velocidad (`0.75x` a `1.4x`), 4 perfiles de timbre (`Natural`, `Voz Grave / Profunda`, `Voz Clara / Aguda`, `Pausada y Cálida`) y selector de voces del sistema.
