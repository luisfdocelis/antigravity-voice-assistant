// ==============================================================================
// Antigravity Voice Assistant — Native IDE Extension
// Integración nativa de voz, accesibilidad y dictado para Antigravity IDE / VS Code
// ==============================================================================

const vscode = require('vscode');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { spawn, exec } = require('child_process');

let serverProcess = null;
let dictationStatusBarItem = null;
let playerStatusBarItem = null;
let currentWebviewView = null;
let activeAudioProcess = null;

/**
 * Activa la extensión en Antigravity IDE
 * @param {vscode.ExtensionContext} context
 */
function activate(context) {
  console.log('[Antigravity Voice] Extensión activada exitosamente.');

  const extensionRoot = context.extensionPath;
  const scriptsDir = path.join(extensionRoot, 'scripts');
  const serverScript = path.join(scriptsDir, 'voice_server.py');
  const sttScript = path.join(scriptsDir, 'voice_stt.py');
  const ttsScript = path.join(scriptsDir, 'voice_tts.py');
  const podcastScript = path.join(scriptsDir, 'voice_podcast.py');

  // --- 1. Inicializar Barra de Estado (Status Bar) ---
  dictationStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 101);
  dictationStatusBarItem.command = 'antigravity-voice.dictate';
  dictationStatusBarItem.text = '$(mic) Dictar';
  dictationStatusBarItem.tooltip = 'Antigravity Voice: Dictar por voz con micrófono (Ctrl+Alt+D)';
  dictationStatusBarItem.show();
  context.subscriptions.push(dictationStatusBarItem);

  playerStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  playerStatusBarItem.command = 'antigravity-voice.openPlayer';
  playerStatusBarItem.text = '$(unmute) Antigravity Voice';
  playerStatusBarItem.tooltip = 'Abrir reproductor accesible en barra lateral';
  playerStatusBarItem.show();
  context.subscriptions.push(playerStatusBarItem);

  // --- 2. Iniciar / Asegurar Servidor Local en Puerto 9000 ---
  ensureVoiceServerRunning(serverScript);

  // --- 3. Registrar Proveedor de Vista en la Barra Lateral (Webview View) ---
  const sidebarProvider = new VoiceAssistantViewProvider(context.extensionUri, extensionRoot);
  context.subscriptions.push(
    vscode.window.registerWebviewViewProvider('antigravity-voice.assistantView', sidebarProvider, {
      webviewOptions: { retainContextWhenHidden: true }
    })
  );

  // --- 4. Comando: Dictar por Voz (Micrófono) ---
  const dictateCmd = vscode.commands.registerCommand('antigravity-voice.dictate', async () => {
    await handleVoiceDictation(sttScript);
  });
  context.subscriptions.push(dictateCmd);

  // --- 5. Comando: Leer Selección de Código en Voz Alta ---
  const readSelectionCmd = vscode.commands.registerCommand('antigravity-voice.readSelection', async () => {
    const editor = vscode.window.activeTextEditor;
    let textToRead = '';
    if (editor && !editor.selection.isEmpty) {
      textToRead = editor.document.getText(editor.selection);
    } else if (editor) {
      textToRead = editor.document.lineAt(editor.selection.active.line).text;
    }

    if (!textToRead || textToRead.trim().length === 0) {
      vscode.window.showInformationMessage('Selecciona código o texto para leer en voz alta.');
      return;
    }

    await speakText(textToRead, ttsScript);
  });
  context.subscriptions.push(readSelectionCmd);

  // --- 6. Comando: Detener Audio ---
  const stopAudioCmd = vscode.commands.registerCommand('antigravity-voice.stopAudio', () => {
    stopActiveAudio();
    if (currentWebviewView) {
      currentWebviewView.webview.postMessage({ command: 'stop' });
    }
    vscode.window.setStatusBarMessage('$(mute) Audio detenido', 2500);
  });
  context.subscriptions.push(stopAudioCmd);

  // --- 7. Comando: Abrir Reproductor Accesible ---
  const openPlayerCmd = vscode.commands.registerCommand('antigravity-voice.openPlayer', () => {
    vscode.commands.executeCommand('antigravity-voice.assistantView.focus');
  });
  context.subscriptions.push(openPlayerCmd);

  // --- 8. Comando: Reiniciar Servidor de Voz ---
  const restartServerCmd = vscode.commands.registerCommand('antigravity-voice.restartServer', () => {
    restartVoiceServer(serverScript);
  });
  context.subscriptions.push(restartServerCmd);

  // --- 9. Comando: Exportar Markdown a Podcast de Audio ---
  const exportPodcastCmd = vscode.commands.registerCommand('antigravity-voice.exportPodcast', async (uri) => {
    const targetUri = uri || (vscode.window.activeTextEditor ? vscode.window.activeTextEditor.document.uri : null);
    if (!targetUri || !targetUri.fsPath.endsWith('.md')) {
      vscode.window.showErrorMessage('Selecciona un archivo Markdown (.md) para exportar como podcast.');
      return;
    }
    await exportPodcast(targetUri.fsPath, podcastScript);
  });
  context.subscriptions.push(exportPodcastCmd);
}

/**
 * Proveedor de Webview para la Barra Lateral
 */
class VoiceAssistantViewProvider {
  constructor(extensionUri, extensionRoot) {
    this._extensionUri = extensionUri;
    this._extensionRoot = extensionRoot;
  }

  resolveWebviewView(webviewView) {
    currentWebviewView = webviewView;
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this._extensionUri]
    };

    const htmlPath = path.join(this._extensionRoot, 'audio_assistant.html');
    let htmlContent = '';
    try {
      if (fs.existsSync(htmlPath)) {
        htmlContent = fs.readFileSync(htmlPath, 'utf8');
      } else {
        htmlContent = '<h2>Error: No se encontró audio_assistant.html</h2>';
      }
    } catch (err) {
      htmlContent = `<h2>Error al cargar reproductor: ${err.message}</h2>`;
    }

    webviewView.webview.html = htmlContent;

    // Manejar mensajes desde el Webview hacia el Host de la Extensión
    webviewView.webview.onDidReceiveMessage(async (message) => {
      switch (message.command) {
        case 'startDictation':
          await vscode.commands.executeCommand('antigravity-voice.dictate');
          break;
        case 'speakText':
          if (message.text) {
            await speakText(message.text, path.join(this._extensionRoot, 'scripts', 'voice_tts.py'));
          }
          break;
        case 'stopAudio':
          vscode.commands.executeCommand('antigravity-voice.stopAudio');
          break;
      }
    });
  }
}

/**
 * Verifica si el servidor en puerto 9000 está activo; si no, lo inicia
 */
function ensureVoiceServerRunning(serverScript) {
  const req = http.get('http://localhost:9000/api/health', (res) => {
    if (res.statusCode === 200) {
      console.log('[Antigravity Voice] Servidor local ya está activo en puerto 9000.');
    } else {
      spawnVoiceServer(serverScript);
    }
  });

  req.on('error', () => {
    console.log('[Antigravity Voice] Iniciando servidor local en segundo plano...');
    spawnVoiceServer(serverScript);
  });

  req.setTimeout(1500, () => {
    req.destroy();
    spawnVoiceServer(serverScript);
  });
}

/**
 * Lanza el proceso de scripts/voice_server.py
 */
function spawnVoiceServer(serverScript) {
  if (!fs.existsSync(serverScript)) return;
  try {
    serverProcess = spawn('python3', [serverScript], {
      detached: true,
      stdio: 'ignore'
    });
    serverProcess.unref();
    console.log('[Antigravity Voice] Servidor voice_server.py iniciado con PID:', serverProcess.pid);
  } catch (err) {
    console.warn('[Antigravity Voice] No se pudo lanzar voice_server.py:', err.message);
  }
}

/**
 * Reinicia el servidor local
 */
function restartVoiceServer(serverScript) {
  if (serverProcess) {
    try {
      process.kill(-serverProcess.pid);
    } catch (_) {}
    serverProcess = null;
  }
  spawnVoiceServer(serverScript);
  vscode.window.showInformationMessage('🎙️ Servidor de voz reiniciado en http://localhost:9000');
}

/**
 * Maneja la captura y transcripción de voz (STT) y la inserta en el editor activo
 */
async function handleVoiceDictation(sttScript) {
  const duration = 5;
  dictationStatusBarItem.text = '$(record~spin) Grabando (5s)...';
  dictationStatusBarItem.color = '#ef4444';

  const progressOptions = {
    location: vscode.ProgressLocation.Notification,
    title: '🎙️ Antigravity Voice: Grabando micrófono...',
    cancellable: false
  };

  await vscode.window.withProgress(progressOptions, async (progress) => {
    progress.report({ increment: 0, message: 'Habla ahora con tu micrófono de Windows...' });

    return new Promise((resolve) => {
      const child = spawn('python3', [sttScript, '--record', '--duration', String(duration)]);
      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (d) => { stdout += d.toString(); });
      child.stderr.on('data', (d) => { stderr += d.toString(); });

      child.on('close', async (code) => {
        dictationStatusBarItem.text = '$(mic) Dictar';
        dictationStatusBarItem.color = undefined;

        const recognizedText = stdout.trim();
        if (code === 0 && recognizedText) {
          // 1. Insertar directamente en el editor activo si existe
          const editor = vscode.window.activeTextEditor;
          if (editor) {
            editor.edit((editBuilder) => {
              editBuilder.insert(editor.selection.active, recognizedText + ' ');
            });
          }

          // 2. Copiar al portapapeles
          await vscode.env.clipboard.writeText(recognizedText);

          // 3. Notificar al usuario
          vscode.window.showInformationMessage(`✓ Dictado: "${recognizedText}" (Copiado al portapapeles)`);

          // 4. Si el Webview está abierto, actualizarlo
          if (currentWebviewView) {
            currentWebviewView.webview.postMessage({
              command: 'transcription',
              text: recognizedText
            });
          }
        } else {
          vscode.window.showWarningMessage('No se detectó audio audible. Asegúrate de hablar cerca de tu micrófono.');
        }
        resolve();
      });
    });
  });
}

/**
 * Reproduce texto en voz alta con la voz neuronal
 */
async function speakText(text, ttsScript) {
  stopActiveAudio();
  vscode.window.setStatusBarMessage('$(unmute~spin) Reproduciendo con Voz Neural...', 4000);

  // Intentar primero reproducir por el servidor local de alta fidelidad si está disponible
  const encoded = encodeURIComponent(text);
  const audioUrl = `http://localhost:9000/api/tts?profile=natural&text=${encoded}`;

  // En Linux/WSL intentamos enviar el audio a los altavoces de Windows si está disponible
  try {
    activeAudioProcess = spawn('python3', [ttsScript, text, '--engine', 'native']);
  } catch (_) {}
}

/**
 * Detiene el audio activo
 */
function stopActiveAudio() {
  if (activeAudioProcess) {
    try {
      activeAudioProcess.kill();
    } catch (_) {}
    activeAudioProcess = null;
  }
}

/**
 * Exporta un archivo Markdown como Podcast
 */
async function exportPodcast(filePath, podcastScript) {
  vscode.window.showInformationMessage('🎙️ Generando podcast en audio desde Markdown...');
  const child = spawn('python3', [podcastScript, filePath]);
  child.on('close', (code) => {
    if (code === 0) {
      vscode.window.showInformationMessage('✓ Podcast de audio generado exitosamente en carpeta dist/podcasts');
    } else {
      vscode.window.showErrorMessage('Error al generar el podcast de audio.');
    }
  });
}

function deactivate() {
  if (serverProcess) {
    try {
      serverProcess.kill();
    } catch (_) {}
  }
  stopActiveAudio();
}

module.exports = {
  activate,
  deactivate
};
