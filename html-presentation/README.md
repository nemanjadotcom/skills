# Cinematic HTML Presentation Builder

A Claude Code skill that turns any brief, outline, script, or rough idea into a **standalone, high-fidelity cinematic HTML presentation** — one self-contained file, no build tools, no external dependencies.

---

## What it produces

- A single `.html` file that runs locally in any browser
- Cinematic editorial design — not a generic slide deck
- Scroll-snap flow with keyboard navigation
- Responsive layout (desktop, tablet, mobile)
- Inline SVG, CSS grain, glass panels, glow rails, parchment cards
- Reduced motion support
- All HTML, CSS, and JavaScript in one file

---

## Installation

Copy `SKILL.md` into your Claude Code skills directory:

```
~/.claude/skills/cinematic-html-presentation-builder/SKILL.md
```

Or drop it into your project's `.claude/skills/` folder for project-scoped use.

---

## Usage

Trigger the skill with any of the following:

> "Make me an HTML presentation about..."
> "Build a cinematic deck for..."
> "Create a visual explainer on..."
> "I have a video script, turn it into an HTML presentation"

Pass in a brief, outline, notes, script, or rough idea. The skill extracts the topic, thesis, narrative arc, and key claims, then builds the full presentation.

---

## Theming

The skill ships with three built-in presets:

| Preset | Feel |
|---|---|
| Dark Cinematic | High contrast, editorial, premium |
| Light Editorial | Clean, professional, readable |
| Night Blue | Focused, technical, deep |

### Custom palette

You can tell Claude exactly which colors to use. The easiest way is to **pick a palette from [coolors.co/palettes/popular](https://coolors.co/palettes/popular)** and paste the hex codes or the palette URL into your prompt.

Example prompt:

> "Use this palette: #0d0d0d, #ff6b6b, #ffd93d, #6bcb77, #4d96ff — dark background, orange-red as the primary accent."

All colors are driven by CSS custom properties in `:root`, so the entire theme is swappable from one block.

---

## Keyboard controls

Every presentation includes:

| Key | Action |
|---|---|
| `↓` / `Space` / `PageDown` | Next section |
| `↑` / `PageUp` | Previous section |
| `F` | Toggle fullscreen |
| `M` | Toggle reduced motion |
| `U` | Toggle UI chrome |

---

## What's inside each presentation

- **Hero** — big title, italic tagline, topic chips
- **Core tension** — what people get wrong and why it matters
- **The shift** — the core mental model or reframe
- **System section** — framework, timeline, map, or stack
- **Main sections** — 3–5 sections, each with a distinct composition
- **Interactive framework** — hoverable layered rows, pillars, or loop diagram
- **Practical playbook** — steps, checklist, or implementation cards
- **Close** — system recap and memorable next action

---

## Section compositions

The skill uses a variety of layouts — no repeated two-column card pattern:

- Centered hero with chips
- Split text + terminal panel
- Split text + parchment diagram
- Full-width interactive framework rows
- Four-card problem grid
- Before/after shift stage
- File-tree architecture panel
- Parchment loop diagram
- Playbook checklist cards
- System map with inline SVG arrows
- Glass dashboard
- Pinned quote or thesis card

---

## Editing existing presentations

Pass in an existing HTML file and ask for changes. The skill preserves your visual system and working interactions, fixes bugs directly, and returns a versioned output — it does not replace your design with a generic template.

---

## License

MIT
