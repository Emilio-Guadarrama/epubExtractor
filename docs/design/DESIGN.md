# Design spec

Direction: **content first, controls float over it.** References: Kindle (grid library, filter chips, mini player, scrubber) and Apple Books (chrome-free reader, glass buttons, `⋯` menu, Contents sheet). Differentiator: Read-Aloud is a first-class feature, not a buried setting.

Status: proposal approved by the owner to proceed with setup. Items marked *(decision)* depend on `docs/decisions/open-decisions.md`.

## Principles

1. Reading screens show almost nothing; controls appear on tap and fade.
2. One accent color *(D-06, proposed amber)*, otherwise system colors, SF Symbols, Dynamic Type.
3. Materials: `.ultraThinMaterial` on iOS 18; `glassEffect` where `#available(iOS 26, *)`. Never break the iOS 18 look.
4. Every screen works in light and dark, on iPhone and iPad, and respects Reduce Motion and VoiceOver labels.

## Information architecture

- Tabs: **Library**, **Settings**. (No store, so no Home or Search tabs.)
- Library → Reader (full screen cover or push). Reader → Contents / Search / Themes & Settings / Listen as sheets.
- iPad: sidebar replaces the tab bar. Android tablet: navigation rail (same IA).

## Library (T-01)

- Default: adaptive cover grid; under each cover, progress `%` and a `⋯` menu (Mark as finished, Share file, Delete).
- List mode (toggle): rows grouped by author, as in Apple Books.
- Top: large title, search field, sort menu (Recent, Title, Author, Progress), view toggle, Import button.
- Filter chips: All, Reading, Unread, Finished, EPUB, PDF.
- "Continue" shelf: the last-opened book large, with progress and a "Resume listening" button when it has been read aloud.
- Covers: real cover when present; otherwise a **generated cover** (deterministic gradient from the title hash, title and author in a serif face). PDF badge on PDFs.
- Books known from sync but without a local file: cloud icon, "Add the file to read here" *(T-06)*.
- Empty state: current ContentUnavailableView with Import.

## Reader (T-02, T-03)

- Full screen. Tap center toggles chrome; edge taps never turn pages in scroll mode.
- Top (glass circles): Close (✕), faded title in the middle, Bookmark.
- Bottom-right floating `⋯` opens a popover: **Listen**, **Contents**, **Search Book**, **Themes & Settings**, **Share**.
- Bottom (when chrome is visible): scrubber with "Section 3 of 41 · 12%". True "Page n of N" arrives only with paged mode (T-11, *D-07*).
- Position and progress: book-wide `%` = characters read / total characters (per-section lengths cached at import).

## Typography and themes (T-02)

- Themes: **Original** (white), **Sepia**, **Gray**, **Night** (true black). Each defines background, text, secondary text, selection, sentence tint and word highlight.
- Fonts: system serif (default), two more serifs bundled or system (e.g. Georgia, Charter/Iowan), a sans, an accessibility face. Size, line spacing, margins, justify + hyphenation (`hyphenationFactor`), paragraph indent toggle.
- Settings persist per device (`@AppStorage`); they are not synced in v1.

## Read-Aloud (T-04)

- Entry points: Listen in the `⋯` menu and a top-bar speaker button.
- Compact floating player over the text: play/pause, back/forward sentence, speed, then a sheet with sleep timer (off, 15, 30, 45, 60 min, end of chapter), voice picker (by language, quality shown), follow-along toggle.
- Highlight: word in accent (45% alpha), sentence tinted (15 to 25%); colors come from the theme.
- Leaving the reader while playing: playback continues and a **mini player** (cover, title, play/pause) floats above the tab bar; tap returns to the reader at the spoken position. *(Today playback stops on leaving; T-04 changes this and must keep all invariants in `review-config.md`.)*
- Lock Screen and Control Center: unchanged from Phase 2 (title, author, cover, play/pause, next/previous section).

## Contents, search, annotations (T-05)

- Contents sheet with segmented tabs: Chapters, Bookmarks, Highlights. Chapter rows show the section number or `%`, current chapter marked.
- Search Book: full-text search over spine text with result snippets; tapping jumps and flashes the match.
- Highlights: long-press selection → color swatches (4 colors) and note. Stored as offsets within a section *(D-11)*.

## Sync affordances (T-06)

- Small cloud/check glyph on covers (on this device, synced, missing file).
- Last-synced time in Settings with "Sync now"; account section (Apple/Google) *(D-10)*.

## Android (T-07 to T-10)

Same IA with Material 3: navigation rail on the Tab S10+, two-pane library and detail, Contents as a side panel in landscape, optional two-page spread. Read-Aloud via `TextToSpeech` + `MediaSession` notification. Visual tokens mirror this document (themes, highlight colors, generated covers).

## Accessibility and quality bar

VoiceOver labels on every control, Dynamic Type in library and menus, 44 pt minimum targets, contrast AA in all four themes, Reduce Motion disables page/scroll animations and cover parallax.
