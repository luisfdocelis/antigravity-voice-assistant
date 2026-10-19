# 🔌 Antigravity Voice Assistant — Guía de Extensión Nativa para Antigravity IDE

> **Versión 3.0.0** · Paquete nativo de extensión (`.vsix`) para Antigravity IDE / VS Code.

---

## 🎯 ¿Qué es la Extensión Nativa de Antigravity IDE?

La extensión nativa de **Antigravity Voice Assistant** transforma las capacidades del plugin en componentes profundamente integrados con la interfaz del IDE:

1. **Barra de Estado (Status Bar)**: Acceso con 1 clic a `$(mic) Dictar` y `$(unmute) Antigravity Voice` en la esquina inferior derecha.
2. **Panel en Barra Lateral (Sidebar View)**: Reproductor accesible, cambio de temas de alto contraste, controles multimedia y perfiles de voz siempre disponibles en la barra de actividades.
3. **Dictado Directo al Cursor**: Al dictar por voz, el texto reconocido se inserta **directamente en el editor de código activo** donde tengas el cursor, y se copia al portapapeles.
4. **Lectura de Código Seleccionado**: Haz clic derecho sobre cualquier bloque de código y selecciona *"Leer Código Seleccionado"* para escucharlo con el diccionario fonético y voces neuronales.
5. **Gestor Automático del Servidor**: La extensión detecta si el servidor local de voz en `localhost:9000` está activo y lo inicia de forma transparente en segundo plano.

---

## 📦 Instalación en Antigravity IDE (Paso a Paso)

El archivo empaquetado de la extensión se encuentra listo en la raíz del repositorio:
`antigravity-voice-assistant-3.0.0.vsix`

### Método 1: Desde la Interfaz Gráfica (Recomendado)
1. Abre **Antigravity IDE**.
2. Presiona <kbd>Ctrl + Shift + X</kbd> (o haz clic en el icono de Extensiones en la barra lateral).
3. Haz clic en el menú de tres puntos (**`...`**) en la esquina superior derecha del panel de extensiones (*Vistas y Más Acciones*).
4. Selecciona **"Instalar desde VSIX..."** (*Install from VSIX...*).
5. Navega a la carpeta del proyecto y selecciona el archivo:
   `antigravity-voice-assistant-3.0.0.vsix`
6. ¡Listo! Verás el nuevo icono en la barra de actividades y el botón `$(mic) Dictar` en la barra de estado.

### Método 2: Desde la Paleta de Comandos
1. Presiona <kbd>Ctrl + Shift + P</kbd>.
2. Escribe: `Extensions: Install from VSIX...`
3. Selecciona `antigravity-voice-assistant-3.0.0.vsix`.

---

## ⌨️ Atajos de Teclado y Comandos Disponibles

| Comando en Paleta (<kbd>Ctrl+Shift+P</kbd>) | Atajo de Teclado | Acción |
| :--- | :--- | :--- |
| `Antigravity Voice: Dictar por Voz con Micrófono` | <kbd>Ctrl + Alt + D</kbd> | Graba tu micrófono de Windows durante 5s e inserta el texto en el cursor. |
| `Antigravity Voice: Leer Código Seleccionado` | <kbd>Ctrl + Alt + R</kbd> | Lee la selección o la línea actual con voz neuronal Microsoft Neural. |
| `Antigravity Voice: Detener Audio` | <kbd>Ctrl + Alt + S</kbd> | Detiene cualquier reproducción auditiva activa al instante. |
| `Antigravity Voice: Abrir Reproductor en Barra Lateral` | — | Abre y enfoca la vista accesible en la barra de actividades. |
| `Antigravity Voice: Reiniciar Servidor Local de Voz` | — | Reinicia el servidor en `localhost:9000` en caso de corte de red. |
| `Antigravity Voice: Exportar como Podcast de Audio` | — | Genera un archivo de podcast narrado a partir de cualquier archivo Markdown. |

---

## ⚙️ Configuración en `settings.json`

Puedes personalizar la extensión desde **Preferencias > Configuración**:

```json
{
  "antigravityVoice.serverPort": 9000,
  "antigravityVoice.dictationDuration": 5,
  "antigravityVoice.voiceProfile": "natural"
}
```

* `antigravityVoice.serverPort`: Puerto local para la síntesis neuronal (por defecto: `9000`).
* `antigravityVoice.dictationDuration`: Duración de captura del micrófono en segundos (por defecto: `5`).
* `antigravityVoice.voiceProfile`: Perfil de voz (`natural`, `clear`, `calm`, `deep`).
