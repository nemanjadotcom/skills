---
name: cinematic-html-presentation-builder
description: Create or edit standalone, high-fidelity cinematic HTML presentations from research briefs, outlines, video notes, scripts, or rough ideas. Use this skill when the user asks for an HTML deck, cinematic presentation, interactive editorial document, visual explainer, scroll-snap story, or wants an existing HTML presentation improved while preserving its visual system.
---

# Cinematic HTML Presentation Builder

## Mission

Turn a user's research brief, video outline, notes, script, or rough idea into a standalone, polished HTML presentation that feels like a cinematic editorial website, not a generic slide deck.

The output must feel finished on the first pass: high contrast, strong editorial typography, cinematic pacing, distinct section compositions, purposeful interaction, responsive behavior, and no placeholder feel.

The default deliverable is one complete self-contained HTML file with all HTML, CSS, SVG, and JavaScript in a single document.

---

## Core output contract

Always produce one complete standalone HTML file unless the user explicitly asks for something else.

The file must:

- Run locally in a browser without build tools.
- Include `<!doctype html>`, `<html>`, `<head>`, `<style>`, `<body>`, and `<script>`.
- Use inline SVG, CSS shapes, gradients, procedural texture, and system fonts.
- Avoid external CDNs, remote scripts, external fonts, and remote images unless the user explicitly asks.
- Use CSS custom properties in `:root`.
- Include semantic sections and readable class names.
- Include desktop, tablet, and mobile responsive behavior.
- Include `prefers-reduced-motion` support.
- Include smooth but restrained interactions.
- Include no missing assets, no placeholder blocks, and no broken visual elements.

When file creation is available, save the result as a versioned `.html` file and return a link or filename.

When file creation is not available, output the full HTML in one code block and tell the user to save it as `index.html` or a descriptive filename.

---

## Theming

Before writing the HTML, ask the user if they have a preferred visual direction or brand palette. If they do, map their colors to the semantic tokens below. If they don't, use the Default Dark Cinematic preset.

All accent colors, backgrounds, and glow values must be driven by CSS custom properties in `:root`. Never hardcode brand colors in individual rules — always reference a variable so the entire theme is swappable from one place.

### Semantic token names

Use these variable names regardless of which preset is chosen:

    :root{
      --bg           /* page background */
      --bg2          /* secondary background, sections */
      --panel        /* glass panel fill */
      --panel2       /* elevated panel fill */
      --text         /* primary text */
      --muted        /* secondary text */
      --faint        /* tertiary / placeholder text */
      --accent-1     /* primary accent — buttons, highlights, active states */
      --accent-2     /* secondary accent — hover, supporting highlights */
      --accent-3     /* tertiary accent — tags, metadata, rails */
      --accent-4     /* quaternary accent — diagrams, success states */
      --accent-5     /* quinary accent — warnings, callouts */
      --accent-6     /* senary accent — links, info states */
      --accent-7     /* error / alert states */
      --paper        /* parchment/warm diagram card background */
      --paper2       /* parchment border/shadow */
      --ink          /* parchment text */
      --line         /* subtle divider / border */
      --glow         /* box-shadow glow using accent-1 */
      --shadow       /* card drop shadow */
      --scene-w      /* max content width */
      --radius       /* default border radius */
    }

### Preset palettes

Pick the preset that best fits the topic and audience, or provide a custom one.

**Preset 1 — Dark Cinematic** (high contrast, editorial, premium)

    --bg:#06070d;
    --bg2:#0b0e18;
    --panel:rgba(18,21,34,.72);
    --panel2:rgba(25,28,44,.84);
    --text:#f4f3f5;
    --muted:#a9abb7;
    --faint:#6f7281;
    --accent-1:#ff8b61;
    --accent-2:#d86f4f;
    --accent-3:#9b86ff;
    --accent-4:#59d99a;
    --accent-5:#e9c75f;
    --accent-6:#7fa7ff;
    --accent-7:#ff695f;
    --paper:#efe1c8;
    --paper2:#dbc39a;
    --ink:#4e3324;
    --line:rgba(255,255,255,.12);
    --glow:0 0 48px rgba(255,139,97,.28);
    --shadow:0 34px 110px rgba(0,0,0,.48), inset 0 1px 0 rgba(255,255,255,.06);
    --scene-w:min(1220px, calc(100vw - 7vw));
    --radius:28px;

**Preset 2 — Light Editorial** (clean, professional, readable)

    --bg:#f5f4f1;
    --bg2:#eceae4;
    --panel:rgba(255,255,255,.82);
    --panel2:rgba(255,255,255,.96);
    --text:#1a1a1e;
    --muted:#5a5a68;
    --faint:#9a9aaa;
    --accent-1:#1a6ef5;
    --accent-2:#1454c4;
    --accent-3:#7c3aed;
    --accent-4:#059669;
    --accent-5:#d97706;
    --accent-6:#0891b2;
    --accent-7:#dc2626;
    --paper:#fff9ee;
    --paper2:#e8d9b8;
    --ink:#3d2b12;
    --line:rgba(0,0,0,.10);
    --glow:0 0 48px rgba(26,110,245,.18);
    --shadow:0 16px 60px rgba(0,0,0,.12), inset 0 1px 0 rgba(255,255,255,.80);
    --scene-w:min(1220px, calc(100vw - 7vw));
    --radius:28px;

**Preset 3 — Night Blue** (focused, technical, deep)

    --bg:#080c14;
    --bg2:#0d1220;
    --panel:rgba(14,20,40,.76);
    --panel2:rgba(20,28,54,.88);
    --text:#e8eaf4;
    --muted:#8b90b0;
    --faint:#5a5f7a;
    --accent-1:#4f9eff;
    --accent-2:#2c7fe0;
    --accent-3:#a78bfa;
    --accent-4:#34d399;
    --accent-5:#fbbf24;
    --accent-6:#22d3ee;
    --accent-7:#f87171;
    --paper:#eef2ff;
    --paper2:#c7d2fe;
    --ink:#1e1b4b;
    --line:rgba(255,255,255,.10);
    --glow:0 0 48px rgba(79,158,255,.28);
    --shadow:0 34px 110px rgba(0,0,0,.56), inset 0 1px 0 rgba(255,255,255,.06);
    --scene-w:min(1220px, calc(100vw - 7vw));
    --radius:28px;

### Applying a custom brand palette

If the user provides specific brand colors, map them to the semantic tokens:

- Primary brand color → `--accent-1`
- Primary hover / darker shade → `--accent-2`
- Secondary brand color → `--accent-3`
- Success / positive → `--accent-4`
- Warning / highlight → `--accent-5`
- Info / link → `--accent-6`
- Error / alert → `--accent-7`
- Background → `--bg`, `--bg2`
- Text → `--text`, `--muted`, `--faint`
- Glow → recompute using `--accent-1` at low opacity

---

## Default visual direction

Overall feel:

- High contrast background.
- Subtle grain.
- Radial lighting.
- Ambient glow.
- Strong contrast.
- Editorial, cinematic, premium.
- Website-grade polish, not "slides."

Visual motifs to use frequently:

- Masked vertical glow rail or timeline.
- Radial scene lighting.
- CSS grain/noise texture.
- Glass panels with glowing borders.
- Capsule labels like `01 · THE QUESTION`.
- Color-coded chips.
- Hoverable cards.
- Terminal/file-tree panels.
- Parchment-style diagram cards.
- Identity/spec cards.
- Interactive layered framework rows.
- Inline SVG arrows, rails, loops, and system maps.
- Progress dots or progress line.
- Subtle cursor glow or ambient glow only if performance remains good.

Never use generic bullet-slide layouts as the main structure. Every section needs a distinct composition.

---

## Typography rules

Use built-in system fonts only unless the user explicitly requests external fonts.

Default type stack:

- Main UI/display: `ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`
- Code: `ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace`
- Italic accent: `Georgia, "Times New Roman", serif`

Headline style:

- Heavy sans-serif.
- Large editorial scale.
- Responsive `clamp()` sizing.
- Tight but readable tracking.
- Italic serif accent words used sparingly.

Spacing guardrails:

- Avoid overly tight negative letter spacing.
- Large heavy sans-serif headlines should generally use `letter-spacing` between `-0.055em` and `-0.025em`.
- Do not use extremely tight tracking like `-0.075em` unless it has been visually checked and does not make words feel glued together.
- Add slight `word-spacing` for large headlines when needed.
- Check letter spacing on hero titles, section headers, card titles, framework labels, and close slides.
- Small uppercase labels may use wide tracking, but body text, metadata, and framework labels must remain easy to scan.
- Serif italic accents should usually be looser than the sans headline, around `-0.018em` to `-0.010em`.

Recommended baseline:

    h1{
      letter-spacing:-.048em;
      word-spacing:.045em;
      line-height:.90;
    }

    h2{
      letter-spacing:-.041em;
      word-spacing:.025em;
      line-height:1;
    }

    h3{
      letter-spacing:-.034em;
      word-spacing:.018em;
      line-height:1.02;
    }

    .serif{
      letter-spacing:-.014em;
    }

---

## Collision-proof layout rules

Prevent text collisions in all responsive layouts.

Use:

- `minmax(0,1fr)` for flexible grid columns.
- `min-width:0` on grid/flex children that contain text.
- `gap` and `column-gap` instead of relying on whitespace.
- `flex-wrap:wrap` for chip rows.
- `overflow:hidden` and `text-overflow:ellipsis` for secondary metadata when needed.
- Mobile breakpoints that stack content instead of squeezing it.

Never let:

- A primary label overlap a secondary label.
- A framework title collide with a right-side descriptor.
- A chip overflow its container.
- A center rail run through important centered content.
- A glow line visually touch or cross a headline or panel.

For layered framework rows, use a collision-safe structure:

    .layer-row{
      display:grid;
      grid-template-columns:52px minmax(0,1fr) auto;
      align-items:center;
      column-gap:22px;
      overflow:hidden;
    }

    .layer-copy{
      min-width:0;
      display:grid;
      grid-template-columns:auto minmax(0,1fr);
      align-items:baseline;
      column-gap:12px;
    }

    .layer-name{
      white-space:nowrap;
    }

    .layer-sub{
      min-width:0;
      white-space:nowrap;
      overflow:hidden;
      text-overflow:ellipsis;
    }

    @media (max-width:1180px){
      .layer-copy{display:block}
      .layer-name,
      .layer-sub{display:block}
      .layer-sub{margin-top:5px}
    }

    @media (max-width:900px){
      .layer-row{
        grid-template-columns:52px minmax(0,1fr);
      }
      .layer-side{display:none}
    }

---

## Center rail rules

A vertical center rail is part of the default cinematic style, but it must never damage readability.

Use one of these strategies:

- Mask the rail behind important centered content.
- Add a `.rail-break` class to sections that need a rail gap.
- Place content above the rail with z-index and add a center background mask behind the section content.
- Move the rail left on mobile.
- Disable or reduce opacity when the composition is dense.

The rail gradient and glow must use the active theme's CSS variables, not hardcoded colors.

Recommended pattern:

    .rail{
      position:fixed;
      top:0;
      bottom:0;
      left:50%;
      width:2px;
      transform:translateX(-50%);
      pointer-events:none;
      background:linear-gradient(180deg,
        transparent 0,
        var(--accent-1) 10%,
        var(--accent-3) 30%,
        var(--accent-4) 50%,
        var(--accent-5) 70%,
        var(--accent-6) 86%,
        transparent 100%);
      box-shadow:var(--glow);
      -webkit-mask-image:linear-gradient(to bottom,#000 0,#000 var(--rail-gap-start),transparent calc(var(--rail-gap-start) + 1px),transparent var(--rail-gap-end),#000 calc(var(--rail-gap-end) + 1px),#000 100%);
      mask-image:linear-gradient(to bottom,#000 0,#000 var(--rail-gap-start),transparent calc(var(--rail-gap-start) + 1px),transparent var(--rail-gap-end),#000 calc(var(--rail-gap-end) + 1px),#000 100%);
    }

JavaScript should update `--rail-gap-start` and `--rail-gap-end` based on the active `.rail-break .scene-inner`.

---

## Required interactions

Every presentation should include:

- Vertical scroll-snap flow.
- Keyboard navigation:
  - `ArrowDown`, `Space`, `PageDown` advance.
  - `ArrowUp`, `PageUp` go back.
  - `F` toggles fullscreen when supported.
  - `M` toggles reduced motion.
  - `U` toggles UI chrome.
- Hover states for cards, chips, buttons, layers, and rows.
- Clickable framework rows, cards, pills, or layers when useful.
- Tooltips for chips and interactive objects when useful.
- Live detail panel for interactive frameworks when useful.
- Progress indicator:
  - Dots, progress line, slide index, or both.
- Smooth but restrained animations.
- Reduced motion mode.

Do not over-animate. The feel should be premium and cinematic, not distracting.

---

## Narrative structure

Turn the brief into a story, not a fact dump.

Default deck structure:

1. Hero/title
   Big title, italic thesis/tagline, short explanation, topic chips.

2. Core tension
   What people get wrong, who it affects, why it matters.

3. The shift
   The core mental model or reframing.

4. System architecture
   Framework, timeline, map, workflow, stack, model, or operating system.

5. Main sections
   3 to 5 sections. Each answers one clear question and pairs text with a designed visual.

6. Interactive framework
   Layers, pillars, loop, map, stack, or operating system. Must be interactive when useful.

7. Practical playbook
   Steps, checklist, prompts, workflow, implementation cards, or operating manual.

8. Recap/close
   Summarize the system and end with a memorable next action.

Keep copy tight. Prefer big visual hierarchy over dense paragraphs.

---

## Content extraction workflow

Before writing HTML, internally extract:

- Topic.
- Audience.
- Goal.
- Thesis.
- Hook.
- Core tension.
- Mental model shift.
- Key claims.
- Framework.
- Examples.
- Action steps.
- Visual metaphors.
- Tone.
- Constraints.
- Required sources or citations.

If the brief is thin, infer a strong narrative and state assumptions briefly only when helpful.

Ask at most 3 clarifying questions only if essential facts are missing. If the user says proceed, proceed.

For current, technical, legal, medical, financial, or fast-changing topics, use research when available and cite sources compactly in the HTML or final note.

Never invent statistics, quotes, claims, or citations.

---

## Section composition patterns

Use a variety of compositions. Do not repeat the same two-column card pattern too often.

Good patterns:

- Centered hero with chips.
- Split text + terminal panel.
- Split text + parchment diagram.
- Full-width interactive framework.
- Four-card problem grid.
- Before/after shift stage.
- File-tree architecture panel.
- Identity/spec card.
- Layered operating system rows with live detail panel.
- Parchment loop diagram.
- Playbook checklist cards.
- Source grid.
- System map with inline SVG arrows.
- Terminal/code shell.
- Horizontal timeline.
- Stack of floating cards.
- Glass dashboard.
- Pinned quote or thesis card.

Each section should have one dominant visual idea.

---

## Component requirements

### Chips

Chips should be colorful, rounded, hoverable, and optionally tooltip-enabled.

Must support wrapping.

Use icons via inline SVG symbols or CSS text glyphs.

### Glass panels

Use translucent backgrounds, glowing borders, inset highlights, and blur.

Avoid unreadable transparency.

### Parchment cards

Use warm paper gradients, subtle procedural texture, border, inner outline, and diagram-like SVG or CSS shapes.

Use `--paper`, `--paper2`, and `--ink` tokens for all parchment surfaces.

Parchment is best for:

- Frameworks.
- Diagrams.
- Maps.
- Loops.
- Hand-drawn explainers.
- Goals.

### Terminal/file-tree panels

Use monospace, dark shell, top traffic dots, and clear folder indentation.

Use for:

- Project structures.
- Commands.
- Code snippets.
- Runtime setup.
- Memory/file systems.
- Workflow examples.

### Interactive layered framework rows

Must include:

- Fixed number badge.
- Main label.
- Secondary metadata.
- Optional right-side descriptor.
- Hover state.
- Active state.
- Live detail panel or tooltip.
- Responsive stacking to avoid overlap.

### Playbook cards

Cards should be clickable when useful.

Clicking can toggle a `done` state and show a small toast.

---

## JavaScript behavior

Implement lightweight vanilla JS only.

Required JS:

- IntersectionObserver for active scene.
- Progress dots creation and active state.
- Scroll navigation function.
- Keyboard event handling.
- Fullscreen toggle.
- Reduced motion toggle.
- UI chrome toggle.
- Tooltip behavior for `[data-tip]`.
- Interactive framework row behavior when present.
- Clickable checklist/playbook behavior when present.
- Rail mask update for `.rail-break` sections when a center rail exists.

Do not use external JS libraries.

Keep JS resilient:

- Guard against missing optional elements.
- Do not throw errors if a component is absent.
- Do not assume every section has the same layout.

---

## Responsive requirements

Desktop:

- Cinematic, spacious, large type.
- Use the center rail when appropriate.
- Keep panels aligned and high impact.

Tablet:

- Reduce huge gaps.
- Stack fragile framework rows when needed.
- Preserve visual hierarchy.

Mobile:

- Use `scroll-snap-type:y proximity` instead of mandatory if necessary.
- Move rail to the left or reduce opacity.
- Stack split layouts.
- Hide side descriptors in framework rows.
- Hide progress dots/controls if they clutter the viewport.
- Ensure cards, chips, file trees, and diagrams do not overflow.

Mobile baseline:

    @media (max-width:900px){
      html{scroll-snap-type:y proximity}
      .scene{place-items:start center; padding:64px 22px}
      .scene-inner::before{display:none}
      .rail{left:28px; opacity:.38}
      .split,
      .split.reverse{grid-template-columns:1fr}
      .controls,
      .dots{display:none}
    }

---

## Accessibility and motion

Include:

- Semantic `<main>` and `<section>`.
- Descriptive `aria-label` for dot navigation and controls.
- `aria-hidden="true"` for decorative SVGs.
- Focus-visible states for buttons.
- Reduced motion support.

Motion rules:

- Use fade-up and subtle transforms.
- Avoid fast spinning, intense parallax, or excessive cursor effects.
- Respect `prefers-reduced-motion`.
- Add a manual reduced-motion toggle with `M`.

Reduced motion baseline:

    @media (prefers-reduced-motion: reduce){
      html{scroll-behavior:auto}
      *,
      *::before,
      *::after{
        animation:none!important;
        transition:none!important;
      }
    }

    body.reduce-motion *,
    body.reduce-motion *::before,
    body.reduce-motion *::after{
      animation:none!important;
      transition:none!important;
      scroll-behavior:auto!important;
    }

---

## Source and citation rules

When the topic requires current or factual support:

- Research with reliable sources when available.
- Use primary sources for technical subjects.
- Add a compact Sources section inside the HTML or a concise final note.
- Do not clutter the deck with long citations.
- Do not invent citations.
- Do not cite claims that are purely the user's opinion or framing.

Source cards should look designed, not like default links.

---

## Editing existing HTML

When editing an existing HTML presentation:

- Modify the existing HTML unless the user asks for a rebuild.
- Preserve the visual system.
- Preserve working interactions.
- Fix bugs directly.
- Return a versioned output file.
- Do not replace the design with a generic template.
- Keep the cinematic quality bar.
- Check for regressions after editing.

Common fixes:

- Loosen overly tight headline letter spacing.
- Add word spacing to large headlines.
- Prevent framework label/sublabel overlap.
- Add `minmax(0,1fr)` and `min-width:0`.
- Stack crowded layout regions at tablet/mobile widths.
- Mask center rails behind key content.
- Increase gap between cards or labels.
- Fix tooltip positioning.
- Fix progress count.
- Fix reduced motion mode.
- Fix mobile overflow.

---

## Quality bar

The first version must look finished.

Before delivery, verify:

- Clear narrative.
- Distinct section compositions.
- Topic-specific visuals.
- Meaningful interactions.
- Offline runnable.
- No broken or missing assets.
- No placeholder content.
- No generic bullet-slide layouts.
- No decorative rail crossing key content.
- Desktop responsive.
- Tablet responsive.
- Mobile responsive.
- Motion is smooth and optional.
- Self-contained file.
- No headline, card title, framework label, chip, or metadata feels glued together.
- No framework row, card row, or label/sublabel pair overlaps.
- Layered rows have clear separation between main label, secondary description, and right-side descriptor.
- Source section is compact and designed when sources are used.
- Final HTML includes all CSS and JS in one file.
- All colors reference CSS custom properties — no hardcoded brand values in individual rules.

---

## Default HTML architecture

Use this structural approach unless the content requires a different layout:

    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>...</title>
      <style>
        :root{
          /* Swap this block to retheme the entire presentation */
          --bg:...;
          --bg2:...;
          --panel:...;
          --panel2:...;
          --text:...;
          --muted:...;
          --faint:...;
          --accent-1:...;
          --accent-2:...;
          --accent-3:...;
          --accent-4:...;
          --accent-5:...;
          --accent-6:...;
          --accent-7:...;
          --paper:...;
          --paper2:...;
          --ink:...;
          --line:...;
          --glow:...;
          --shadow:...;
          --scene-w:min(1220px, calc(100vw - 7vw));
          --radius:28px;
        }
        ...
      </style>
    </head>
    <body>
      <svg width="0" height="0" aria-hidden="true">
        <!-- inline symbols -->
      </svg>

      <div class="cursor-glow" aria-hidden="true"></div>
      <div class="rail" aria-hidden="true"></div>
      <div class="progress-line" aria-hidden="true"></div>
      <div class="dots" aria-label="Presentation sections"></div>
      <div class="tooltip" id="tooltip"></div>
      <div class="toast" id="toast"></div>

      <main class="deck" id="deck">
        <section class="scene hero center rail-break" data-title="Hook">
          ...
        </section>
        ...
      </main>

      <div class="controls" aria-label="Presentation controls">
        ...
      </div>

      <script>
        (() => {
          ...
        })();
      </script>
    </body>
    </html>

---

## Final response format

When delivering a new HTML presentation:

- Provide the downloadable HTML link when available.
- Mention the filename.
- Briefly list built-in controls:
  - Arrow / Space / PageDown advance.
  - ArrowUp / PageUp go back.
  - `F` fullscreen.
  - `M` reduced motion.
  - `U` hide UI.
- Ask for specific iteration requests around content, fidelity, motion, layout, or branding.

When delivering a `SKILL.md`, provide the full markdown content in one block and give the suggested save path.

---

## Default tone

Be decisive, editorial, and practical.

Do not over-explain process.

Do not apologize for producing a strong first version.

Do not call the design a wireframe, draft, or skeleton.

The output should feel like a finished cinematic artifact.
