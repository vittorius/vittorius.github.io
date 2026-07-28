# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this is

A personal blog built with [Zola](https://www.getzola.org/) (static site
generator, local version 0.22.1), published at `https://vittorius.github.io`.
Config lives in `zola.toml`.

## Commands

```bash
zola serve          # dev server with live reload (http://127.0.0.1:1111)
zola build          # write the site to public/
zola check          # validate content + external links without building
```

There is no test suite, package manager, or lint step — Zola is the only
toolchain.

## Implementation routine

After implementing a TODO item (found in as unchecked item in `TODO.md`), mark
it as checked.

## Architecture: the light/dark theming layer

The site was migrated from the
[Hook](https://github.com/InputUsername/zola-hook) theme to
[Pickles](https://github.com/lukehsiao/zola-pickles), and Hook's light/dark
toggle was ported. The `themes/hook` submodule has since been removed; only its
ported light/dark logic remains, referenced below for historical context.

**Why `sass/_theme.scss` exists.** Pickles has no CSS-variable layer — it styles
everything from compile-time SCSS variables in
`themes/zola-pickles/sass/_variables.scss` (Selenized White, `lab()` colors like
`$bg_0`, `$fg_0`, `$blue`), which bake into the output CSS and cannot be swapped
at runtime. Those variables also **cannot be shadowed**:
`themes/zola-pickles/sass/base.scss` opens with `@import "variables"`, which
Sass resolves relative to the theme dir, so any earlier redefinition is
overwritten before a rule is emitted.

So `sass/_theme.scss` instead:

1. Defines two `@mixin`s of CSS custom properties — **Selenized White** (light,
   identical to the theme's own values) and **Selenized Black** (dark).
2. Applies them in two layers: `:root` + `@media (prefers-color-scheme: dark)`
   as the no-JS default, then `:root.light-mode` / `:root.dark-mode` —
   specificity (0,2,0) beats (0,1,0) — for an explicit choice.
3. **Re-declares** every color-bearing rule pointing at `var(--…)`. Selectors
   are reproduced **verbatim from the theme** so specificity matches and later
   source order wins. This is why `@import "theme"` must stay **last** in
   `sass/style.scss`.

Consequences for anyone touching colors:

- New colored rules belong in `sass/_theme.scss` using `var(--fg-0)`,
  `var(--bg-1)`, `var(--blue)` etc. — never a literal, or it won't switch.
- If you re-declare a theme rule, **copy its selector exactly**; a "tidied"
  selector changes specificity and silently stops overriding.
- The theme sets no page background at all (it relies on browser-default white
  and uses `$bg_0` only on `table tr`). `body { background-color: var(--bg-0) }`
  in `_theme.scss` is load-bearing for dark mode.
- All 22 Selenized slots are defined, but the theme only ever uses `bg_0/1/2`,
  `dim_0`, `fg_0/1`, `blue`, `br_blue`.

**The toggle itself** lives in `templates/index.html`: an inline script in
`<head>` (deliberately _outside_ the `extra_head` block, so no child template
can drop it) sets `light-mode`/`dark-mode` on `<html>` before first paint to
avoid a flash; buttons plus click handlers sit at the end of `<body>`. The
choice persists in `localStorage["theme"]` (Hook used `sessionStorage`), falling
back to `prefers-color-scheme`. Icons are `static/{dark,light}_mode.svg`, copied
from Hook — their hardcoded fills are correct by construction, since the black
moon only renders in light mode and the white sun only in dark.

**The saved choice expires after 6 hours.** `setTheme` also writes
`localStorage["theme_saved_at"] = Date.now()`, and the head script clears both
keys (reverting to `prefers-color-scheme`) when `theme_saved_at` is missing or
older than 6h. Every explicit toggle refreshes the timestamp, so only 6h of
inactivity resets the choice; a legacy `theme` value with no timestamp is
treated as stale and cleared on first load. The check lives in the pre-paint
head script so the revert applies before first paint (no flash).

**Code blocks do not follow the toggle.** `zola.toml`'s
`[markdown.highlighting] theme = "gruvbox-dark-soft"` bakes colors into inline
`style` attributes, so they stay dark in both modes; this was a deliberate scope
cut. Making them adaptive needs class-based highlighting and two generated
stylesheets that share class names with no scoping. Also unverified: whether
`[markdown.highlighting] theme` is even a valid Zola 0.22 key (classic Zola used
`[markdown] highlight_theme`) — if it is silently ignored, code blocks aren't
highlighted at all today.

## Architecture: how the theme is overridden

`zola.toml` sets `theme = "zola-pickles"` and `compile_sass = true`. Nothing in
`themes/` should be edited directly — customization happens through two override
channels.

**Templates — shadowing by filename.** Zola resolves `templates/<name>` in the
site root before `themes/zola-pickles/templates/<name>`. `templates/index.html`
is a _verbatim copy_ of the theme's `index.html` with local edits. Because the
theme's `page.html`, `tags/*.html`, and `categories/*.html` all
`{% extends "index.html" %}`, that resolution lands on the root copy — so
**`templates/index.html` is the base layout for every page on the site**. Its
extension points are the blocks `seo`, `js`, `css`, `extra_head`, `header`,
`header_nav`, `content`, `webring`, `footer`.

The theme's `title`, `description` and `meta` blocks were **replaced by a single
`seo` block** — see the SEO section below. A child template that still declares
`{% block title %}` (the theme's own `page.html` does) is silently dropped by
Tera, because the parent no longer declares a block by that name.

Not every root template is a copy. `templates/page.html`,
`templates/tags/single.html` and `templates/categories/single.html` shadow their
theme counterparts, and `page.html` shows the cheaper idiom:
`{% extends "zola-pickles/templates/page.html" %}` — Zola registers theme
templates under their full path as well as their bare name, so you can extend
the file you are shadowing and override only the blocks you care about.

**Sass — import chain.** `sass/style.scss` compiles to `public/style.css` (the
only stylesheet the layout links) and is just two imports:

```scss
@import "../themes/zola-pickles/sass/base.scss"; // theme, unmodified
@import "./overrides/themes/zola-pickles/base.scss"; // local overrides, applied after
@import "theme"; // light/dark layer — must stay last
```

The override tree under `sass/overrides/themes/zola-pickles/` **mirrors the
theme's SCSS paths** — e.g. `object/component/_article.scss` overrides the theme
file of the same relative path. `overrides/.../base.scss` is the entry point and
re-imports each override partial. Keep new override partials `_`-prefixed and
mirror-pathed.

Known cruft from this setup: the override entry point lacks a leading
underscore, so Zola also compiles it standalone to
`public/overrides/themes/zola-pickles/base.css`; and the theme's own `base.scss`
compiles to `public/base.css`. Neither file is linked by any template. (This is
why partials must keep their `_` prefix — `sass/_theme.scss` would otherwise
also emit a stray `public/theme.css`.)

Also orphaned:
`sass/overrides/themes/zola-pickles/object/component/_pagination.scss` is
imported by nothing, so its `.c-pagination { margin-top: auto }` never applies
and the footer-at-bottom fix is incomplete.

**Careful with `zola serve`:** it writes compiled assets into the output dir,
which is the tracked `public/`. Use `zola serve -o <tmpdir>` /
`zola build -o <tmpdir>` when you don't intend to modify committed files.

## Architecture: the SEO / metadata layer

**One file owns all page metadata.** `templates/partials/seo.html` emits
`<title>`, the meta description, Open Graph, Twitter Card, `rel=canonical`,
`meta author`, `article:*` and the feed `<link>`; it ends by including
`templates/partials/schema.html` for JSON-LD. It is included from the `seo`
block in `templates/index.html`, which every template inherits — so it reaches
posts, standalone pages, taxonomy list and term pages, pagination and the 404
without a single per-template override.

**Do not add metadata anywhere else.** The previous split (theme `index.html`
holding site-wide defaults, theme `page.html` overriding two of the three
blocks) is exactly how the site ended up with `og:url` hardcoded to the base URL
on every post and no canonical anywhere.

Page type is detected from whichever context variable Zola defined:

| Defined | Page type |
| --- | --- |
| `page` | post, or standalone page when `page.components[0] == "pages"` |
| `term` | a tag/category term page |
| `taxonomy` (no `term`) | a taxonomy list page |
| `section` with a title | a section index |
| none / no `current_url` | `404.html` |

`current_url` is the canonical for everything, and it is already the pager URL
on `/page/2/` (verified against a build) — pagination self-canonicalises rather
than pointing back at page 1. `404.html` is the one template Zola renders
without `current_url`; it gets `noindex, follow` and deliberately **no**
canonical, since it stands for every unmatched path.

**Tera constraints this layer ran into** (all cost a build failure to discover):

- `self::macro()` inside an `{% include %}`d partial resolves against the
  _rendering root_, not the partial — so `partials/json_macros.html` is imported
  in `templates/index.html`, not where it is used.
- Imports must sit at the very top of a template, before any comment or markup.
- A filter cannot appear mid-concatenation: `"x" ~ label | lower ~ "y"` is a
  parse error. Precompute the filtered value into its own variable.
- `set_global` parses arithmetic but not boolean logic — `set_global x = not (a and b)`
  fails; use an `{% if %}`.
- Tera has no `\u` string escape. The `</script>` guard in `json_macros.html`
  rewrites `</` to `<\/` (a legal JSON escape) instead.
- Autoescape turns every `/` in a URL into `&#x2F;`. URLs emitted into
  attributes carry `| safe`; **text values must not**, so a quote in a post
  title stays escaped.

**Icons and the share card.** `static/favicon.svg` and `static/og-default.svg`
are the editable sources; the rasterised `favicon.ico`, `apple-touch-icon.png`
and `og-default.png` are what ship. ImageMagick here is built **without librsvg
and without Freetype** — it silently drops SVG strokes and cannot draw text at
all — so rasterising goes through macOS Quick Look, which needs the sandbox
disabled:

```bash
cd static
qlmanage -t -s 512 -o . favicon.svg
magick favicon.svg.png -resize 180x180 -strip apple-touch-icon.png
magick favicon.svg.png -define icon:auto-resize=48,32,16 favicon.ico
qlmanage -t -s 1200 -o . og-default.svg
magick og-default.svg.png -crop 1200x630+0+285 +repage -strip og-default.png
rm -f favicon.svg.png og-default.svg.png
```

`og-default.svg` is authored on a **1200×1200** canvas with the card in a
translated group at y=285. Quick Look renders a square document 1:1 but scales
and clips a non-square one, hence the square source and the crop.

## Content conventions

- **Posts go in the root of `content/`.** Pickles requires this — its
  `index.html` paginates `paginator.pages` from the root section.
  `content/_index.md` holds `paginate_by` / `sort_by = "date"` /
  `insert_anchor_links`.
- Filenames carry a date prefix (`2026-07-10-first.md`) but the published date
  comes from the `date` field in the TOML front matter, not the filename.
- `content/pages/` holds standalone pages (e.g. `about.md`). Its `_index.md`
  sets `render = false`: the section is a container, not a destination, but it
  must exist or `partials/header_menu.html`'s
  `get_section(path="pages/_index.md")` fails the build. Pages opt into the
  header nav with `[extra] include_in_header = true`, and **must not set
  `date`** — Zola's site-wide feed carries every page that has one, so a dated
  `about.md` shows up as a feed entry. `templates/page.html` renders the
  date/reading-time byline only when `page.date` is present.
- **Give every post a front-matter `description`** (≤ ~155 chars). It is what
  `partials/seo.html` uses for the meta description, `og:description` and the
  JSON-LD; without it the description falls back to `page.summary` and then to a
  truncation of the body, which reads poorly in search results.
- Use `aliases = ["old/path/"]` when a slug changes — Zola emits redirect stubs,
  so inbound links and accumulated ranking survive.
- Theme shortcodes available: `figure`, `table`, `katex`, `youtube`, `vimeo`.
  Use `<!-- more -->` to control the summary shown in the post list — otherwise
  the first 280 characters are used.

## Repo gotchas

- **`themes/zola-pickles/` is a git submodule** (`.gitmodules` points at
  `https://github.com/lukehsiao/zola-pickles.git`). Run
  `git submodule update --init` after a fresh checkout to populate it. The old
  `themes/hook` submodule has been removed.
- **`public/` is gitignored** and untracked. Publishing goes through
  `.github/workflows/deploy.yml`, which builds with `getzola/github-pages` on
  every push to `gh-pages`; the `deploy` skill force-resets `gh-pages` to `main`
  to trigger it. `gh-pages` is a **source mirror**, not build output.
- `zola.toml`'s `[extra].links` (Email/GitHub/LinkedIn) is rendered in the
  footer with `rel="me"` and reused as the schema.org `Person.sameAs` in
  `partials/schema.html`. Set `me = false` on an entry to keep it out of both —
  a `mailto:` is not a profile URL.
- **Zola generates `robots.txt` and `sitemap.xml` itself**, and the built-in
  robots.txt already carries a `Sitemap:` line. Do not hand-write either;
  `exclude_paginated_pages_in_sitemap = "all"` in `zola.toml` is what keeps
  `/page/N/` out of the sitemap.
- Tera comments are `{# … #}`, not `<!-- -->`. Commit 5949281 exists
  specifically to fix this; the disabled dark-mode block depends on it.
- `.zed/settings.json` maps `.html` to the Tera (HTML) language and sets
  `tab_size: 2`.
