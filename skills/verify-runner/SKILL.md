---
name: "verify-runner"
description: "Executes local validation suite (manifest syntax, python scripts, HTML validity, and documentation checks) before commits and PRs."
---

# Verify Runner Skill — Antigravity Voice Assistant 🎙️

This skill runs and audits local validation suites for **Antigravity Voice Assistant** before committing, pushing, or creating Pull Requests.

---

## 📌 Validation Modes

### 1. Fast Manifest & Syntax Validation
Validates core files in under 2 seconds:
- `plugin.json` JSON validation.
- All Python scripts compilation check (`python3 -m py_compile scripts/*.py`).
- YAML frontmatter check across all `skills/*/SKILL.md`.

```bash
# Validate plugin manifest
python3 -m json.tool plugin.json > /dev/null

# Validate CLI Python scripts
python3 -m py_compile scripts/*.py
```

### 2. Full Verification Suite (`.agents/scripts/verify.sh`)
- `--docs-only`: Validates markdown links, headers, and documentation parity.
- `--manifest`: Validates plugin manifest structure and suggested prompts.
- `--all`: Comprehensive validation across all project assets.

---

## 🛑 Pre-Push Blocker Protocol

If any validation step fails (exit code `!= 0`), changes must not be pushed until:
1. Manifest JSON errors or YAML formatting defects are resolved.
2. Template inline JavaScript syntax errors are corrected.
3. Fallback logic functions properly without uncaught exceptions.
