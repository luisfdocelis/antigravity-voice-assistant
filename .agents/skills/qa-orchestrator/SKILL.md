---
name: "qa-orchestrator"
description: "Comprehensive QA orchestrator for Antigravity Voice Assistant. Coordinates unit testing, JSON/HTML validation, accessibility standards (WCAG AAA), cross-platform voice validation, and Quality Gates."
---

# QA Orchestrator Skill — Antigravity Voice Assistant 🎙️

This skill acts as the **Central Quality Assurance Orchestrator (QA Lead & Gatekeeper)** for **Antigravity Voice Assistant**. It guarantees that all code modifications, HTML template updates, accessibility widgets, and voice synthesis scripts pass the **5 Quality Gates** before integration.

---

## 🏛️ Delegation Matrix and Specialized Subagents

| Delegated Subagent | Skill / Path | Responsibilities |
| :--- | :--- | :--- |
| **test-generator** | [skills/test-generator/SKILL.md](../test-generator/SKILL.md) | Unit test generation (Python `pytest` / JS Web Speech mocks) and edge cases. |
| **verify-runner** | [skills/verify-runner/SKILL.md](../verify-runner/SKILL.md) | Automated validation execution (`plugin.json`, Python syntax, HTML validity). |
| **code-review-runner** | [skills/code-review-runner/SKILL.md](../code-review-runner/SKILL.md) | Accessibility audit, WCAG contrast verification (#ffffff text), and security check. |
| **bug-hunter** | [skills/bug-hunter/SKILL.md](../bug-hunter/SKILL.md) | Root cause analysis (RCA) for playback, speech synthesis, and UI issues. |

---

## 🔺 Testing Pyramid for Antigravity Voice Assistant

```text
               / \
              /   \
             / E2E \           Layer 4: Full Chat Integration & <agent-embed> rendering
            /-------\
           / Contrato\         Layer 3: plugin.json manifest schema, SKILL.md frontmatter
          /-----------\
         / Integración \       Layer 2: Local CLI bridge (scripts/voice_tts.py) & Audio API
        /---------------\
       /    Unitarias    \     Layer 1: Speech prep, language detection, markdown render
      /-------------------\
```

1. **Layer 1 — Core Logic & Parser Unit Tests:**
   - Markdown parsing (`renderMarkdown`).
   - Natural spoken text formatting (`prepareTextForSpeech`): headers, bullet points, numbers, links.
   - Multilingual auto-detection logic (`detectLanguage`).
2. **Layer 2 — Integration & Audio Engine:**
   - Multi-engine switching (`Web Speech API`, `Local CLI`, `Cloud Neural`).
   - Native platform voice synthesis via `scripts/voice_tts.py` (Linux `piper`/`espeak`, macOS `say`, Windows `SAPI`).
3. **Layer 3 — Manifest & Accessibility Standards (WCAG 2.1 AAA):**
   - High contrast compliance: pure white text (`#ffffff`) on dark background (`#0b1120`).
   - Scalable typography (`14px` to `36px`).
   - Manifest validation (`plugin.json` valid JSON and schema-compliant).
4. **Layer 4 — Embeddable UI & Performance:**
   - Embed rendering performance within `<agent-embed>` without layout shift.
   - Smooth volume and speed control reactivity.

---

## 🛡️ The 5 Mandatory Quality Gates

| Quality Gate | Pass Criteria | Validation Tool |
| :--- | :--- | :--- |
| **Gate 1: Manifest & Syntax Hygiene** | Valid `plugin.json`, valid YAML frontmatter in all `SKILL.md`, and clean Python scripts. | `python3 -m json.tool plugin.json` / `python3 -m py_compile scripts/*.py` |
| **Gate 2: Speech & Unit Suite** | 100% of unit tests pass (text parser, language heuristics, voice mapping). | `python3 -m pytest` / JS test runners |
| **Gate 3: Accessibility & High Contrast (WCAG AAA)** | Verified pure white text `#ffffff`, focus rings `#facc15`, font scaling `14px-36px`. | Visual & DOM inspection |
| **Gate 4: Documentation & i18n Parity** | `README.md`, `plugin.json` and `SKILL.md` aligned with latest features and language support. | `./.agents/scripts/verify.sh --docs-only` |
| **Gate 5: Cross-Platform TTS Safety** | Verified fallback hierarchy: Cloud API -> System CLI -> Web Speech API. | `code-review-runner` |
