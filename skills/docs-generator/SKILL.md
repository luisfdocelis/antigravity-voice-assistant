---
name: "docs-generator"
description: "Technical writing, architecture documentation, Mermaid diagrams, accessibility guides, and multilingual documentation maintenance."
---

# Docs Generator Skill — Antigravity Voice Assistant 🎙️

This skill governs the creation and maintenance of technical documentation for **Antigravity Voice Assistant**: installation guides, architecture diagrams, accessibility standards, theme palettes, and multilingual documentation.

---

## 📌 Documentation Areas

1. **User Guide & Manifest (`README.md`, `plugin.json`):**
   - High-contrast visual themes catalog (11 DaisyUI + 5 developer themes).
   - Speed (`0.5x` to `2.0x`) and volume control usage.
   - Triple voice engine configuration (Web Speech API, Local CLI, Cloud Neural).
   - Global and workspace-level installation commands.
2. **Accessible Assistant Rules (`rules/AGENTS.md`):**
   - Pure white text rules (`#ffffff`) on dark backgrounds (`#0b1120`).
   - Embedding protocols using `<agent-embed>`.
   - Concise hierarchical structuring (using `##` headings, bold items, and short numbered steps).
3. **Skill Catalogs (`skills/*/SKILL.md`):**
   - Clear YAML frontmatter with actionable descriptions.
   - Practical workflows, parameters, and code snippets.

---

## 📏 Technical Writing & Accessibility Rules

1. **Large & Hierarchical Headings:** Always use clear markdown hierarchy (`##` for sections) so low-vision readers have distinct visual breaks.
2. **Mermaid Diagrams:** Use standard, supported types (`flowchart`, `sequenceDiagram`, `stateDiagram-v2`) with properly quoted node labels.
3. **Multilingual Consistency:** Maintain documentation parity between English and Spanish where applicable.
