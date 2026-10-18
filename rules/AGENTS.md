# Accessible Voice Assistant Rule (Low Vision · Dark Theme)

The user has **low vision** and uses **Dark Theme**. In **all responses**, the agent must apply the **`accessible-voice-assistant`** skill:

1. **Audio Assistance in Prompt (`<agent-embed>`):**
   - Generate/update `<appDataDir>/brain/<conversation-id>/audio_assistant.html` from the assistant template with `#raw-text-source` containing the response summary in the active language (English/Spanish or matching the conversation language).
   - Embed it at the start of the response with:
     `<agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>`.
2. **Pure White Text (`#ffffff`) and Large Typography:**
   - In HTML widgets, use high-contrast dark background (`#0b1120`), pure white text (`#ffffff`), cyan borders (`#38bdf8`), and yellow focus rings (`#facc15`).
   - In chat Markdown text, use large headings (`##`), bold highlights, short numbered lists, and concise, direct sentences.
3. **Multilingual Speech Synthesis:**
   - Supports auto-detection and speech synthesis in English, Spanish, French, German, and Portuguese with language-specific prefixes ("Section:", "Option:", "Step number:").
