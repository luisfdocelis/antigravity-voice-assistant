// ==============================================================================
// Antigravity Voice Assistant — Clean Native IDE Extension
// Integración de voz para el prompt y chat de Antigravity IDE
// ==============================================================================

const vscode = require('vscode');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

let dictateStatusBarItem = null;
let readStatusBarItem = null;
let stopStatusBarItem = null;
let currentAudioPanel = null;
let activeEngineProcess = null;
let lastSpokenText = '';

/**
 * Activa la extensión en Antigravity IDE
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  console.log('[Antigravity Voice] Extensión activada desde cero.');

  const extensionRoot = context.extensionPath;
  const engineScript = path.join(extensionRoot, 'scripts', 'voice_engine.py');

  // --- 1. Botón: Dictar Prompt (Ctrl+Alt+D) ---
  dictateStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 102);
  dictateStatusBarItem.command = 'antigravity-voice.dictatePrompt';
  dictateStatusBarItem.text = '$(mic) Dictar Prompt';
  dictateStatusBarItem.tooltip = 'Habla para escribir o refinar un prompt en el chat de Antigravity (Ctrl+Alt+D)';
  dictateStatusBarItem.show();
  context.subscriptions.push(dictateStatusBarItem);

  // --- 2. Botón: Leer Respuesta (Ctrl+Alt+R) ---
  readStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 101);
  readStatusBarItem.command = 'antigravity-voice.readResponse';
  readStatusBarItem.text = '$(unmute) Leer Respuesta';
  readStatusBarItem.tooltip = 'Lee en voz alta la respuesta del chat o el texto seleccionado (Ctrl+Alt+R)';
  readStatusBarItem.show();
  context.subscriptions.push(readStatusBarItem);

  // --- 3. Botón: Detener Audio (Ctrl+Alt+S) ---
  stopStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  stopStatusBarItem.command = 'antigravity-voice.stopAudio';
  stopStatusBarItem.text = '$(mute) Detener';
  stopStatusBarItem.tooltip = 'Detener reproducción de audio actual (Ctrl+Alt+S)';
  stopStatusBarItem.hide();
  context.subscriptions.push(stopStatusBarItem);

  // --- 4. Registrar Comandos ---

  // Comando: Dictar Prompt
  context.subscriptions.push(
    vscode.commands.registerCommand('antigravity-voice.dictatePrompt', async () => {
      await handleDictatePrompt(engineScript);
    })
  );

  // Comando: Leer Respuesta o Selección
  context.subscriptions.push(
    vscode.commands.registerCommand('antigravity-voice.readResponse', async () => {
      await handleReadResponse(context, engineScript);
    })
  );

  // Comando: Detener Audio
  context.subscriptions.push(
    vscode.commands.registerCommand('antigravity-voice.stopAudio', () => {
      stopCurrentAudio();
    })
  );
}

/**
 * Maneja la captura de micrófono y la inyección directa en el prompt del chat
 */
async function handleDictatePrompt(engineScript) {
  if (!fs.existsSync(engineScript)) {
    vscode.window.showErrorMessage('No se encontró scripts/voice_engine.py');
    return;
  }

  const config = vscode.workspace.getConfiguration('antigravityVoice');
  const duration = config.get('dictateDuration', 5);
  const lang = config.get('language', 'es-ES');

  dictateStatusBarItem.text = '$(record~spin) Escuchando... habla ahora';
  dictateStatusBarItem.color = '#ef4444';

  const progressOptions = {
    location: vscode.ProgressLocation.Notification,
    title: '🎙️ Antigravity Voice: Escuchando micrófono...',
    cancellable: true
  };

  await vscode.window.withProgress(progressOptions, async (progress, token) => {
    progress.report({ increment: 0, message: `Habla ahora (${duration} segundos)...` });

    return new Promise((resolve) => {
      let cancelled = false;
      token.onCancellationRequested(() => {
        cancelled = true;
        if (activeEngineProcess) {
          activeEngineProcess.kill();
          activeEngineProcess = null;
        }
        resetDictateButton();
        resolve();
      });

      const args = [engineScript, '--dictate', '--duration', String(duration), '--lang', lang];
      const proc = spawn('python3', args, { env: process.env });
      activeEngineProcess = proc;

      let stdout = '';
      let stderr = '';

      proc.stdout.on('data', (d) => { stdout += d.toString(); });
      proc.stderr.on('data', (d) => { stderr += d.toString(); });

      proc.on('close', async (code) => {
        activeEngineProcess = null;
        resetDictateButton();

        if (cancelled) return resolve();

        try {
          const result = JSON.parse(stdout.trim());
          if (result.success && result.text) {
            const transcribed = result.text.trim();

            // INYECCIÓN DIRECTA EN EL PROMPT DEL CHAT DE ANTIGRAVITY
            // isPartialQuery: true coloca el texto en la caja de prompt sin enviarlo de inmediato
            // permitiendo al usuario refinarlo o presionar Enter para enviar.
            await vscode.commands.executeCommand('workbench.action.chat.open', {
              query: transcribed,
              isPartialQuery: true
            });

            vscode.window.showInformationMessage(`🎙️ Prompt reconocido: "${transcribed}"`);
          } else {
            const errMsg = result.error || stderr || 'No se reconoció voz clara.';
            vscode.window.showWarningMessage(`🎙️ ${errMsg}`);
          }
        } catch (e) {
          vscode.window.showWarningMessage(`🎙️ No se pudo procesar la voz: ${stdout || stderr || e.message}`);
        }
        resolve();
      });

      proc.on('error', (err) => {
        activeEngineProcess = null;
        resetDictateButton();
        vscode.window.showErrorMessage(`Error ejecutando motor de voz: ${err.message}`);
        resolve();
      });
    });
  });
}

/**
 * Restaura el estado visual del botón de dictado
 */
function resetDictateButton() {
  if (dictateStatusBarItem) {
    dictateStatusBarItem.text = '$(mic) Dictar Prompt';
    dictateStatusBarItem.color = undefined;
  }
}

/**
 * Lee la respuesta actual del chat, el texto seleccionado o el portapapeles
 */
async function handleReadResponse(context, engineScript) {
  let textToSpeak = '';

  // 1. Si hay texto seleccionado en el editor activo
  const editor = vscode.window.activeTextEditor;
  if (editor && !editor.selection.isEmpty) {
    textToSpeak = editor.document.getText(editor.selection).trim();
  }

  // 2. Si no hay selección, leer del portapapeles
  if (!textToSpeak) {
    try {
      const clipboard = await vscode.env.clipboard.readText();
      if (clipboard && clipboard.trim().length > 3) {
        textToSpeak = clipboard.trim();
      }
    } catch (_) {}
  }

  // 3. Si aún no hay texto, pedirlo al usuario
  if (!textToSpeak) {
    const input = await vscode.window.showInputBox({
      prompt: 'Ingresa o pega el texto de Antigravity que deseas escuchar:',
      placeHolder: 'Texto para síntesis de voz neural...'
    });
    if (!input) return;
    textToSpeak = input.trim();
  }

  lastSpokenText = textToSpeak;
  const config = vscode.workspace.getConfiguration('antigravityVoice');
  const voice = config.get('voice', 'es-ES-AlvaroNeural');
  const rate = config.get('rate', 1.0);

  readStatusBarItem.text = '$(sound-max) Sintetizando...';
  stopStatusBarItem.show();

  const tmpMp3 = path.join(context.extensionPath, 'scripts', 'temp_playback.mp3');

  const args = [engineScript, '--speak', textToSpeak, '--voice', voice, '--rate', String(rate), '--output', tmpMp3];
  const proc = spawn('python3', args, { env: process.env });
  activeEngineProcess = proc;

  let stdout = '';
  let stderr = '';

  proc.stdout.on('data', (d) => { stdout += d.toString(); });
  proc.stderr.on('data', (d) => { stderr += d.toString(); });

  proc.on('close', (code) => {
    activeEngineProcess = null;

    if (code !== 0 || !fs.existsSync(tmpMp3)) {
      readStatusBarItem.text = '$(unmute) Leer Respuesta';
      stopStatusBarItem.hide();
      vscode.window.showErrorMessage(`Error al generar voz neural: ${stderr || stdout}`);
      return;
    }

    // Reproducir a través de un Webview de audio nativo en Electron
    playAudioInWebview(context, tmpMp3);
  });
}

/**
 * Reproduce el archivo MP3 generado a través de un panel Webview nativo en Electron
 */
function playAudioInWebview(context, mp3Path) {
  readStatusBarItem.text = '$(sound-max) Reproduciendo...';

  if (currentAudioPanel) {
    currentAudioPanel.dispose();
  }

  currentAudioPanel = vscode.window.createWebviewPanel(
    'antigravityAudioPlayer',
    'Antigravity Voice Player',
    { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true },
    { enableScripts: true, localResourceRoots: [vscode.Uri.file(path.dirname(mp3Path))] }
  );

  const fileUri = currentAudioPanel.webview.asWebviewUri(vscode.Uri.file(mp3Path));

  currentAudioPanel.webview.html = `
    <!DOCTYPE html>
    <html lang="es">
    <head>
      <meta charset="UTF-8">
      <style>
        body {
          background-color: #0b1120;
          color: #ffffff;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          padding: 20px;
          box-sizing: border-box;
          text-align: center;
        }
        .card {
          background: #1e293b;
          border: 1px solid #38bdf8;
          border-radius: 12px;
          padding: 24px;
          max-width: 480px;
          box-shadow: 0 4px 20px rgba(0,0,0,0.5);
        }
        h2 { color: #38bdf8; margin-top: 0; font-size: 1.2rem; }
        p { color: #facc15; font-size: 0.95rem; margin-bottom: 16px; }
        audio { width: 100%; border-radius: 8px; outline: none; }
      </style>
    </head>
    <body>
      <div class="card">
        <h2>🔊 Antigravity Voice Assistant</h2>
        <p>Reproduciendo respuesta con voz neuronal Álvaro...</p>
        <audio src="${fileUri}" autoplay controls></audio>
      </div>
      <script>
        const audio = document.querySelector('audio');
        audio.addEventListener('ended', () => {
          // Finalizó la reproducción
        });
      </script>
    </body>
    </html>
  `;

  currentAudioPanel.onDidDispose(() => {
    currentAudioPanel = null;
    readStatusBarItem.text = '$(unmute) Leer Respuesta';
    stopStatusBarItem.hide();
  });
}

/**
 * Detiene la reproducción actual de audio
 */
function stopCurrentAudio() {
  if (currentAudioPanel) {
    currentAudioPanel.dispose();
    currentAudioPanel = null;
  }
  if (activeEngineProcess) {
    activeEngineProcess.kill();
    activeEngineProcess = null;
  }
  readStatusBarItem.text = '$(unmute) Leer Respuesta';
  stopStatusBarItem.hide();
  vscode.window.showInformationMessage('Audio detenido.');
}

/**
 * Desactiva la extensión
 */
function deactivate() {
  stopCurrentAudio();
}

module.exports = {
  activate,
  deactivate
};
