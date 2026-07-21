# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal blog built with [Zola](https://www.getzola.org/) (static site generator, local version 0.22.1), published at `https://vittorius.github.io`. Config lives in `zola.toml`.

## Commands

```bash
zola serve          # dev server with live reload (http://127.0.0.1:1111)
zola build          # write the site to public/
zola check          # validate content + external links without building
```

There is no test suite, package manager, or lint step — Zola is the only toolchain.

## Architecture: the light/dark theming layer

The site was migrated from the [Hook](https://github.com/InputUsername/zola-hook) theme to [Pickles](https://github.com/lukehsiao/zola-pickles), and Hook's light/dark toggle was ported. `themes/hook/` stays in the repo purely as the reference implementation.

**Why `sass/_theme.scss` exists.** Pickles has no CSS-variable layer — it styles everything from compile-time SCSS variables in `themes/zola-pickles/sass/_variables.scss` (Selenized White, `lab()` colors like `$bg_0`, `$fg_0`, `$blue`), which bake into the output CSS and cannot be swapped at runtime. Those variables also **cannot be shadowed**: `themes/zola-pickles/sass/base.scss` opens with `@import "variables"`, which Sass resolves relative to the theme dir, so any earlier redefinition is overwritten before a rule is emitted.

So `sass/_theme.scss` instead:

1. Defines two `@mixin`s of CSS custom properties — **Selenized White** (light, identical to the theme's own values) and **Selenized Black** (dark).
2. Applies them in two layers: `:root` + `@media (prefers-color-scheme: dark)` as the no-JS default, then `:root.light-mode` / `:root.dark-mode` — specificity (0,2,0) beats (0,1,0) — for an explicit choice.
3. **Re-declares** every color-bearing rule pointing at `var(--…)`. Selectors are reproduced **verbatim from the theme** so specificity matches and later source order wins. This is why `@import "theme"` must stay **last** in `sass/style.scss`.

Consequences for anyone touching colors:

- New colored rules belong in `sass/_theme.scss` using `var(--fg-0)`, `var(--bg-1)`, `var(--blue)` etc. — never a literal, or it won't switch.
- If you re-declare a theme rule, **copy its selector exactly**; a "tidied" selector changes specificity and silently stops overriding.
- The theme sets no page background at all (it relies on browser-default white and uses `$bg_0` only on `table tr`). `body { background-color: var(--bg-0) }` in `_theme.scss` is load-bearing for dark mode.
- All 22 Selenized slots are defined, but the theme only ever uses `bg_0/1/2`, `dim_0`, `fg_0/1`, `blue`, `br_blue`.

**The toggle itself** lives in `templates/index.html`: an inline script in `<head>` (deliberately *outside* the `extra_head` block, so no child template can drop it) sets `light-mode`/`dark-mode` on `<html>` before first paint to avoid a flash; buttons plus click handlers sit at the end of `<body>`. The choice persists in `localStorage["theme"]` (Hook used `sessionStorage`), falling back to `prefers-color-scheme`. Icons are `static/{dark,light}_mode.svg`, copied from Hook — their hardcoded fills are correct by construction, since the black moon only renders in light mode and the white sun only in dark.

**Code blocks do not follow the toggle.** `zola.toml`'s `[markdown.highlighting] theme = "gruvbox-dark-soft"` bakes colors into inline `style` attributes, so they stay dark in both modes; this was a deliberate scope cut. Making them adaptive needs class-based highlighting and two generated stylesheets that share class names with no scoping. Also unverified: whether `[markdown.highlighting] theme` is even a valid Zola 0.22 key (classic Zola used `[markdown] highlight_theme`) — if it is silently ignored, code blocks aren't highlighted at all today.

## Architecture: how the theme is overridden

`zola.toml` sets `theme = "zola-pickles"` and `compile_sass = true`. Nothing in `themes/` should be edited directly — customization happens through two override channels.

**Templates — shadowing by filename.** Zola resolves `templates/<name>` in the site root before `themes/zola-pickles/templates/<name>`. `templates/index.html` is a *verbatim copy* of the theme's `index.html` with local edits. Because the theme's `page.html`, `tags/*.html`, and `categories/*.html` all `{% extends "index.html" %}`, that resolution lands on the root copy — so **`templates/index.html` is the base layout for every page on the site**. Its extension points are the blocks `title`, `description`, `meta`, `js`, `css`, `extra_head`, `header`, `content`, `webring`, `footer`.

**Sass — import chain.** `sass/style.scss` compiles to `public/style.css` (the only stylesheet the layout links) and is just two imports:

```scss
@import "../themes/zola-pickles/sass/base.scss";   // theme, unmodified
@import "./overrides/themes/zola-pickles/base.scss"; // local overrides, applied after
@import "theme";                                     // light/dark layer — must stay last
```

The override tree under `sass/overrides/themes/zola-pickles/` **mirrors the theme's SCSS paths** — e.g. `object/component/_article.scss` overrides the theme file of the same relative path. `overrides/.../base.scss` is the entry point and re-imports each override partial. Keep new override partials `_`-prefixed and mirror-pathed.

Known cruft from this setup: the override entry point lacks a leading underscore, so Zola also compiles it standalone to `public/overrides/themes/zola-pickles/base.css`; and the theme's own `base.scss` compiles to `public/base.css`. Neither file is linked by any template. (This is why partials must keep their `_` prefix — `sass/_theme.scss` would otherwise also emit a stray `public/theme.css`.)

Also orphaned: `sass/overrides/themes/zola-pickles/object/component/_pagination.scss` is imported by nothing, so its `.c-pagination { margin-top: auto }` never applies and the footer-at-bottom fix is incomplete.

**Careful with `zola serve`:** it writes compiled assets into the output dir, which is the tracked `public/`. Use `zola serve -o <tmpdir>` / `zola build -o <tmpdir>` when you don't intend to modify committed files.

## Content conventions

- **Posts go in the root of `content/`.** Pickles requires this — its `index.html` paginates `paginator.pages` from the root section. `content/_index.md` holds `paginate_by` / `sort_by = "date"` / `insert_anchor_links`.
- Filenames carry a date prefix (`2026-07-10-first.md`) but the published date comes from the `date` field in the TOML front matter, not the filename.
- `content/pages/` holds standalone pages (e.g. `about.md`).
- Theme shortcodes available: `figure`, `table`, `katex`, `youtube`, `vimeo`. Use `<!-- more -->` to control the summary shown in the post list — otherwise the first 280 characters are used.

## Repo gotchas

- **`themes/zola-pickles/` is untracked and uncommitted** — a plain `git clone`, not a submodule. `.gitmodules` still declares only the *old* `themes/hook` submodule. A fresh checkout will not have the active theme.
- **`public/` is committed to git** with no `.gitignore`, but it currently contains only compiled CSS/JS/fonts — **no HTML**. It is not a deployable build. There is no CI workflow in the repo; an `origin/gh-pages` branch exists. Confirm the intended publishing path before treating a `public/` commit as a deploy.
- `zola.toml` still defines `[extra].links` (Email/GitHub/LinkedIn). That was consumed by Hook's header; **Pickles ignores it**, so those links currently render nowhere.
- `templates/index.html:54` guards the Atom feed link with `config.generate_feed` (singular), while `zola.toml` sets `generate_feeds` (plural, the correct Zola 0.19+ key). The feed `<link>` therefore never renders.
- Tera comments are `{# … #}`, not `<!-- -->`. Commit 5949281 exists specifically to fix this; the disabled dark-mode block depends on it.
- `.zed/settings.json` maps `.html` to the Tera (HTML) language and sets `tab_size: 2`.
