# App Identity: AmpX Rename

**Date:** 2026-09-11
**Status:** Approved — ready for implementation plan
**Product:** AmpX — *Modern audio player. Classic spirit.*
**Approach:** Big-bang mechanical rename; clean break on user data
**Related:** [2026-08-02-enthea-visualizer-design.md](./2026-08-02-enthea-visualizer-design.md) (ENTHEA naming stays)

## Goal

Give the app its own name and its own face, so it stands on its own rather than as "a Winamp clone" — without losing the compact-player design that is the whole point of it.

## Non-goals

- Abandoning the compact floating-window concept, the 275 px geometry, or the detachable playlist/EQ/visualizer model
- Rewriting the UI architecture — `WinampPanel*` types are renamed to `AmpXPanel*`, not redesigned
- Changing the MIT licence or removing upstream attribution to `mbrukman/winamp-macos`, Matt Greenwood, or Webamp
- UserDefaults / Application Support / security-scoped bookmark migration (clean break by design)
- New skin / visual redesign (tracked as a later work item)
- Legal opinion on trademark availability — light clearance only; recorded below

## Decisions (locked)

| Topic | Choice |
|---|---|
| Product name | **AmpX** |
| Tagline | **Modern audio player. Classic spirit.** |
| GitHub repo / local folder | **`ampx`** (`ratovarius/ampx`, `~/ampx`) |
| Bundle identifier | **`com.ampx.macos`** / `com.ampx.macos.tests` |
| Type / target prefix | **`AmpX*`** (`AmpXApp`, `AmpX.xcodeproj`, scheme `AmpX`, …) |
| Visualizer | **ENTHEA** stays ENTHEA |
| User-data migration | **None** — clean break; old `com.winamp.macos` data abandoned |
| Rename style | **Big-bang** — one behaviour-neutral commit for in-repo surfaces |
| Attribution | README keeps fork lineage and Webamp reference |
| Clearance bar | **Light** — GitHub + App Store + web + Homebrew cask; no EUIPO/USPTO |
| Visual identity (skin) | Separate, later work item — rename is not blocked on redrawing the skin |
| Rejected name | **`Reamp`** — `Reamp.app` in the repo root is a third-party macOS player, not this project |

## Light clearance (2026-09-11)

Not a legal opinion. Recorded so the rename is not blind:

| Source | Finding |
|---|---|
| Homebrew cask API | No cask token/name containing `ampx` |
| GitHub | Many unrelated `ampx` / AMP (Accelerated Mobile Pages) repos. Closest product-ish hit: [`Hari-Patel1/AmpX`](https://github.com/Hari-Patel1/AmpX) (Flutter MP3 player). `ratovarius/ampx` is free |
| App Store | Near-matches only: `LQ AMP-X` (DSP amp remote), `Amplx` (social/blockchain), `AmptX` (HIIT timer) — none are a macOS local music player named AmpX |
| Web | No established macOS AmpX music player found in a quick search |

Proceed under the agreed light-check bar. Revisit if shipping commercially or to the App Store under this mark.

## Architecture

### Rename surface

| Area | Items |
|---|---|
| Build | `PRODUCT_BUNDLE_IDENTIFIER` ×2, target name, scheme, `Winamp.xcodeproj` → `AmpX.xcodeproj`, `Package.swift` target/product, `build.sh` `PROJECT_NAME`, `bump-version.sh`, `create-dmg.sh` |
| Scripts | `scripts/run-tests.sh` (`-scheme AmpX`), `scripts/shoot.sh` (matches windows by app name — **breaks silently** if missed: empty screenshots), `scripts/pyproject.toml`, `scripts/winamp_fixtures/` → `scripts/ampx_fixtures/` (+ regenerate `uv.lock`) |
| Signing | Code-signing identity references, entitlements file name, notarization `--primary-bundle-id`, and any keychain profile named for the old bundle ID |
| Bundle | `CFBundleName`, `CFBundleDisplayName`, `CFBundleIdentifier`, document types / UTIs, AppIcon asset names if they embed Winamp |
| Defaults keys | **Do not migrate.** New bundle ID → fresh suite. Leave key strings alone unless they must change for another reason; no copy-from-old-suite path |
| Source | `WinampApp`, `WinampColors`, `WinampCommands`, `WinampDockGraph`, `WinampPanelColumnPack`, `WinampPanelDescriptor`, `WinampPanelLayoutState`, `WinampPanelPlacement`, `WinampPanelPositionStore`, `WinampPanelWindowManager`, `WinampSkinSprites`, `Audio/WinampEQBands` → `AmpX*` equivalents |
| Tests | `Tests/WinampTests/` → `Tests/AmpXTests/`, `WinampEQBandsTests` → `AmpXEQBandsTests` |
| Docs | README (lead with AmpX + tagline), AGENTS.md, CLAUDE.md, USAGE.md, BUILDING.md, RELEASE.md, CHANGES.md, `docs/**` project references. Historical “Winamp 2.x / Webamp” aesthetic lineage stays where it describes geometry or upstream |
| Repo | `gh repo rename ampx`; update `origin` remote and URLs in README/RELEASE. Local folder `winamp-macos` → `ampx` **last** (Cursor workspace path) |

### Not renamed

- `upstream` remote → `mbrukman/winamp-macos`
- ENTHEA types, docs, and manual
- Classic skin sprite coordinates / Webamp geometry comments
- MIT license copyright lines for upstream authors
- The word “Winamp” in prose that means the historical product or UX inspiration

### User data (explicit non-migration)

A new bundle identifier means macOS treats AmpX as a different app: fresh `UserDefaults`, fresh Application Support, invalid security-scoped bookmarks.

**Chosen behavior:** clean break. Do not implement `IdentityMigration`. Document in RELEASE.md that installing AmpX does not import state from the old `com.winamp.macos` build; both may coexist on disk as separate apps.

### Visual independence (separate work item)

The rename addresses the word. The Classic UI remains a close reproduction of Winamp 2.x’s visual design. An original sprite sheet / palette / control shapes at the same 275 px geometry is sequenced **after** library and DJ-mode work. ENTHEA already proves original visual work can ship in this project.

## Error handling & edge cases

| Case | Behavior |
|---|---|
| Old and new app both present on disk | Separate apps, separate data. Document in RELEASE.md; do not delete the old one |
| Fresh AmpX install | Empty prefs / empty playlist — expected |
| `shoot.sh` app-name match missed | Empty screenshots rather than an error — verify after rename |
| Cursor open on `~/winamp-macos` during folder rename | Move the folder only after code lands and the user can reopen the workspace at `~/ampx` |
| Partial rename (types renamed, bundle ID not) | Forbidden — single atomic in-repo commit |
| Name later found taken for commercial use | Spec revised; display name can change without another full type rename if needed |

## Testing

| Area | Expectations |
|---|---|
| Build | Clean build under the new target/scheme; `./build.sh --release` and `create-dmg.sh` produce correctly named artifacts |
| Scripts | `./scripts/run-tests.sh` under scheme `AmpX`; `./scripts/shoot.sh` still captures windows |
| Migration | **N/A** — no migration code; no migration tests |
| Regression | Entire suite green after the rename commit — behaviour-neutral |
| Manual | Launch AmpX; confirm display name, About/menus, and that old Winamp-named prefs are not expected to appear |

## Files expected to change

Effectively every file that embeds the old name (prefix rename), plus:

- `Winamp.xcodeproj/` → `AmpX.xcodeproj/` (including `project.pbxproj` and `AmpX.xcscheme`)
- `Package.swift`, `build.sh`, `bump-version.sh`, `create-dmg.sh`
- `scripts/run-tests.sh`, `scripts/shoot.sh`, `scripts/pyproject.toml`, `scripts/winamp_fixtures/` → `ampx_fixtures/`, `scripts/uv.lock`
- `Resources/` asset catalogue names if needed
- `README.md`, `AGENTS.md`, `CLAUDE.md`, `USAGE.md`, `BUILDING.md`, `RELEASE.md`, `CHANGES.md`
- This spec (status → approved)

**Not created:** `IdentityMigration.swift` / migration tests (out of scope).

## Execution order

1. Land this approved spec
2. Mechanical in-repo rename (types, project, scripts, docs) — one behaviour-neutral commit
3. Verify build + `./scripts/run-tests.sh` + smoke `shoot.sh`
4. `gh repo rename ampx`; update remotes and any remaining URLs
5. Local folder rename `winamp-macos` → `ampx` when ready to reopen Cursor

## Success criteria

1. Light clearance recorded in this spec (done above)
2. One behaviour-neutral rename commit; full test suite green before and after
3. No migration path; RELEASE.md states the clean break
4. `./build.sh --release` and `create-dmg.sh` produce AmpX-named artifacts
5. GitHub repo is `ratovarius/ampx`; README leads with AmpX + tagline and keeps upstream attribution
6. ENTHEA remains the visualizer name

## Risks

| Risk | Mitigation |
|---|---|
| Giant rename diff hides a real change | Mechanical rename only; no refactors in the same commit; review for non-substitution edits |
| Silent empty screenshots after rename | Explicit `shoot.sh` verification step |
| Workspace path breaks mid-session | Folder rename last |
| Name collision if shipping commercially later | Light clearance noted; revisit before App Store / trademark filing |
| Skin still looks like Winamp | Accepted for this work item; visual independence is deferred |
