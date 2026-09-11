# AmpX Rename Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mechanically rename the project from Winamp → AmpX across types, build, scripts, docs, GitHub, and the local folder — behaviour-neutral, no prefs migration.

**Architecture:** Big-bang in-repo substitution (`Winamp*` → `AmpX*`, bundle `com.ampx.macos`, repo/folder `ampx`), then GitHub rename + local folder move last. No `IdentityMigration`. ENTHEA and upstream attribution stay.

**Tech Stack:** Swift 6, Xcode `AmpX.xcodeproj`, SPM `Package.swift`, bash scripts, `uv` fixtures (`ampx_fixtures`), `gh` for GitHub

**Spec:** `docs/superpowers/specs/2026-09-11-app-identity-design.md`

## Global Constraints

- Product name **AmpX**; tagline **Modern audio player. Classic spirit.**
- Bundle IDs: **`com.ampx.macos`** / **`com.ampx.macos.tests`**
- Type / target / scheme / `.app` prefix: **`AmpX`**
- Repo and local folder: **`ampx`**
- **No** UserDefaults / Application Support / bookmark migration
- **Do not** rename ENTHEA types or `docs/enthea-manual/` product meaning
- Keep upstream attribution to `mbrukman/winamp-macos` and Webamp; keep prose that means historical Winamp 2.x UX
- Mechanical rename only — **no refactors, no behaviour changes** in the same commit
- Do **not** touch `Reamp.app/` (third-party binary in repo root)
- Do **not** rewrite `.worktrees/`
- No commits unless the user explicitly asks
- Folder rename (`~/winamp-macos` → `~/ampx`) is **last** and requires user readiness (Cursor workspace path)

## File map

| Path | Role after rename |
|---|---|
| `Sources/AmpX*.swift`, `Sources/Utilities/AmpX*.swift`, `Sources/Audio/AmpXEQBands.swift` | Renamed types/files from `Winamp*` |
| `Tests/AmpXTests/` | Renamed test target directory |
| `AmpX.xcodeproj/` (+ `AmpX.xcscheme`) | Xcode project / scheme |
| `Package.swift` | SPM name/product/target `AmpX` |
| `Resources/AmpX.entitlements` | Was `Winamp.entitlements` |
| `Resources/Assets.xcassets/AmpXIcon.imageset/`, `AmpXSkin.imageset/` | Asset set renames; PNG filenames follow |
| `build.sh`, `bump-version.sh`, `create-dmg.sh` | `PROJECT_NAME=AmpX` |
| `scripts/run-tests.sh`, `scripts/shoot.sh` | Project/scheme/app name `AmpX`; shot paths `/tmp/ampx_shot*.png` |
| `scripts/ampx_fixtures/` | Was `ampx_fixtures`; `pyproject.toml` + `uv.lock` |
| `README.md`, `AGENTS.md`, `CLAUDE.md`, `USAGE.md`, `BUILDING.md`, `RELEASE.md`, `CHANGES.md` | AmpX identity + tagline; RELEASE notes clean break |
| `docs/**` | Project-name references → AmpX where they mean *this* app |

---

### Task 1: Baseline — suite green before rename

**Files:**
- None modified

**Interfaces:**
- Consumes: current `AmpX.xcodeproj` / scheme `Winamp`
- Produces: confirmation that HEAD is green so post-rename failures are rename bugs

- [ ] **Step 1: Run the full test suite**

```bash
./scripts/run-tests.sh
```

Expected: all tests PASS (fixtures generated, `xcodebuild test` under scheme `Winamp`).

- [ ] **Step 2: Record a quick inventory for the rename commit message**

```bash
find Sources Tests -name 'Winamp*.swift' | sort | tee /tmp/ampx-rename-swift-files.txt
rg -l '\bWinamp[A-Za-z0-9_]*\b|com\.winamp\.macos|Winamp\.xcodeproj|ampx_fixtures' \
  --glob '!.git/**' --glob '!.build/**' --glob '!.worktrees/**' --glob '!Reamp.app/**' \
  --glob '!docs/enthea-manual/shots/**' | sort | tee /tmp/ampx-rename-touch-list.txt
```

Expected: ~22 `Winamp*.swift` source files + 5 test files; touch list includes build scripts and docs.

- [ ] **Step 3: Stop — do not commit** (baseline only)

---

### Task 2: Rename Swift types and files (`Winamp*` → `AmpX*`)

**Files:**
- Rename (git mv): every path in `/tmp/ampx-rename-swift-files.txt`
- Modify: every Swift file under `Sources/` and `Tests/` that references `Winamp…` symbols (including non-`Winamp*.swift` call sites such as `ContentView.swift`, Classic views, Enthea bridges)

**Interfaces:**
- Consumes: existing `AmpXApp`, `AmpXColors`, `AmpXCommands`, `AmpXDockGraph`, `AmpXPanel*`, `AmpXSkinSprites`, `AmpXEQBands`, `AmpXUIScale`, `AmpXHotkeys`, `AmpXMenuCatalog`, `AmpXMetrics`, `AmpXTypography`, `WinampTimeFormatting`, `WinampPlaylistKeyboard`, `AmpXWindowConfigurator`, `AmpXWindowSnap`
- Produces: identical APIs under `AmpX*` names (e.g. `@main struct AmpXApp`, `AmpXUIScale.shared`, `AmpXHotkeys.handle(...)`)

- [ ] **Step 1: `git mv` each `Winamp*.swift` file to `AmpX*.swift`**

```bash
while IFS= read -r src; do
  dst=$(echo "$src" | sed 's/Winamp/AmpX/g')
  mkdir -p "$(dirname "$dst")"
  git mv "$src" "$dst"
done < /tmp/ampx-rename-swift-files.txt
```

Expected: `git status` shows renames only for those paths; `Tests/AmpXTests/` still named that (Task 3).

- [ ] **Step 2: Mechanically replace Swift identifiers `Winamp` → `AmpX` in Sources and Tests**

Use a word-boundary-safe pass so comments about historical “Winamp 2.x” in Classic files are **not** blindly destroyed. Prefer replacing the type prefix pattern:

```bash
# Identifier / type prefix only (WinampFoo → AmpXFoo). Review the diff for prose.
rg -l '\bWinamp[A-Za-z0-9_]*\b' Sources Tests --glob '*.swift' | while IFS= read -r f; do
  perl -i -pe 's/\bWinamp([A-Za-z0-9_]*)/AmpX$1/g' "$f"
done
```

Also rename the test directory contents’ type names (files already moved if they were `Winamp*Tests.swift`).

Expected examples after edit:

```swift
@main
struct AmpXApp: App {
    @StateObject private var uiScale = AmpXUIScale.shared
    @StateObject private var panelLayout = AmpXPanelLayoutState()
    // ...
    .commands {
        AmpXCommands(
            audioPlayer: self.audioPlayer,
            playlistManager: self.playlistManager,
            uiScale: self.uiScale,
            panelLayout: self.panelLayout
        )
    }
}
```

- [ ] **Step 3: Spot-check that historical prose still says “Winamp” where intended**

```bash
rg -n 'Winamp 2\.x|classic Winamp|original Winamp|Webamp' Sources --glob '*.swift' | head -40
rg -n '\bWinamp\b' Sources Tests --glob '*.swift' | head -40
```

Expected: remaining `\bWinamp\b` hits are aesthetic/historical comments only — **zero** leftover `WinampFoo` type names.

```bash
rg -n '\bWinamp[A-Za-z]' Sources Tests --glob '*.swift' || echo 'OK: no Winamp* identifiers'
```

Expected: `OK: no Winamp* identifiers`

- [ ] **Step 4: Do not commit yet** — Xcode project still points at old paths (Task 3)

---

### Task 3: Xcode project, scheme, entitlements, assets, Package.swift

**Files:**
- Rename: `AmpX.xcodeproj` → `AmpX.xcodeproj`
- Rename: `AmpX.xcodeproj/xcshareddata/xcschemes/Winamp.xcscheme` → `AmpX.xcscheme` (inside new project)
- Rename: `Tests/AmpXTests` → `Tests/AmpXTests`
- Rename: `Resources/Winamp.entitlements` → `Resources/AmpX.entitlements`
- Rename: `Resources/Assets.xcassets/WinampIcon.imageset` → `AmpXIcon.imageset` (and `winamp-icon.png` → `ampx-icon.png` if present)
- Rename: `Resources/Assets.xcassets/WinampSkin.imageset` → `AmpXSkin.imageset` (and `winamp-skin.png` → `ampx-skin.png` if present)
- Modify: `AmpX.xcodeproj/project.pbxproj` (all Winamp path/name/bundle strings)
- Modify: `AmpX.xcscheme`
- Modify: `Package.swift`
- Modify: asset `Contents.json` filenames

**Interfaces:**
- Consumes: Task 2 file paths (`Sources/AmpXApp.swift`, …)
- Produces: scheme `AmpX`, products `AmpX.app` / `AmpXTests.xctest`, bundles `com.ampx.macos` / `com.ampx.macos.tests`

- [ ] **Step 1: Rename project, tests dir, entitlements, assets**

```bash
git mv AmpX.xcodeproj AmpX.xcodeproj
git mv AmpX.xcodeproj/xcshareddata/xcschemes/Winamp.xcscheme \
      AmpX.xcodeproj/xcshareddata/xcschemes/AmpX.xcscheme
git mv Tests/AmpXTests Tests/AmpXTests
git mv Resources/Winamp.entitlements Resources/AmpX.entitlements

git mv Resources/Assets.xcassets/WinampIcon.imageset \
      Resources/Assets.xcassets/AmpXIcon.imageset
git mv Resources/Assets.xcassets/WinampSkin.imageset \
      Resources/Assets.xcassets/AmpXSkin.imageset

# Rename PNG payloads if they embed winamp in the filename
if [[ -f Resources/Assets.xcassets/AmpXIcon.imageset/winamp-icon.png ]]; then
  git mv Resources/Assets.xcassets/AmpXIcon.imageset/winamp-icon.png \
         Resources/Assets.xcassets/AmpXIcon.imageset/ampx-icon.png
fi
if [[ -f Resources/Assets.xcassets/AmpXSkin.imageset/winamp-skin.png ]]; then
  git mv Resources/Assets.xcassets/AmpXSkin.imageset/winamp-skin.png \
         Resources/Assets.xcassets/AmpXSkin.imageset/ampx-skin.png
fi
```

- [ ] **Step 2: Update `Contents.json` filenames inside the image sets**

In `Resources/Assets.xcassets/AmpXIcon.imageset/Contents.json`, set `"filename" : "ampx-icon.png"`.
In `Resources/Assets.xcassets/AmpXSkin.imageset/Contents.json`, set `"filename" : "ampx-skin.png"`.

- [ ] **Step 3: Rewrite `project.pbxproj` strings**

```bash
perl -i -pe '
  s/AmpXTests/AmpXTests/g;
  s/Winamp\.entitlements/AmpX.entitlements/g;
  s/WinampIcon/AmpXIcon/g;
  s/WinampSkin/AmpXSkin/g;
  s/Winamp\.app/AmpX.app/g;
  s/com\.winamp\.macos/com.ampx.macos/g;
  s/\bWinamp\b/AmpX/g;
' AmpX.xcodeproj/project.pbxproj
```

Then fix any Swift path entries that still say `Winamp` in filenames (should already be `AmpX` after Task 2 `git mv` — verify):

```bash
rg -n 'Winamp' AmpX.xcodeproj/project.pbxproj || echo 'OK: pbxproj clean'
```

Expected: `OK: pbxproj clean`. If hits remain, they are bugs — fix before building.

Confirm the critical settings exist:

```bash
rg -n 'PRODUCT_BUNDLE_IDENTIFIER|TEST_HOST|CODE_SIGN_ENTITLEMENTS|path = AmpX' AmpX.xcodeproj/project.pbxproj | head -40
```

Expected excerpts:

```
PRODUCT_BUNDLE_IDENTIFIER = com.ampx.macos;
PRODUCT_BUNDLE_IDENTIFIER = com.ampx.macos.tests;
CODE_SIGN_ENTITLEMENTS = Resources/AmpX.entitlements;
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/AmpX.app/Contents/MacOS/AmpX";
path = AmpXTests;
```

- [ ] **Step 4: Update `AmpX.xcscheme`**

```bash
perl -i -pe 's/Winamp/AmpX/g' AmpX.xcodeproj/xcshareddata/xcschemes/AmpX.xcscheme
rg -n 'Winamp' AmpX.xcodeproj/xcshareddata/xcschemes/AmpX.xcscheme || echo 'OK: scheme clean'
```

- [ ] **Step 5: Update `Package.swift`**

Replace the entire file with:

```swift
// swift-tools-version: 6.0
import PackageDescription

/// Secondary build-smoke package (no asset catalog / XCTest target).
/// Run the real suite via `./scripts/run-tests.sh` and `AmpX.xcodeproj`.
let package = Package(
    name: "AmpX",
    platforms: [
        // Xcode 26.4 SDK max deployment target is 26.4.99; product floor remains macOS 26.5+.
        .macOS("26.4")
    ],
    products: [
        .executable(name: "AmpX", targets: ["AmpX"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AmpX",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
```

- [ ] **Step 6: Smoke-compile with xcodebuild (no full test yet)**

```bash
xcodebuild -project AmpX.xcodeproj -scheme AmpX -destination 'platform=macOS,arch=arm64' build ONLY_ACTIVE_ARCH=YES
```

Expected: **BUILD SUCCEEDED**. If file-not-found errors, pbxproj still points at old `Winamp*.swift` paths — fix those entries.

- [ ] **Step 7: Do not commit yet** — scripts still say Winamp (Task 4)

---

### Task 4: Build / release scripts and Python fixtures

**Files:**
- Modify: `build.sh`, `bump-version.sh`, `create-dmg.sh`
- Modify: `scripts/run-tests.sh`, `scripts/shoot.sh`, `scripts/generate-fixtures.sh` (if it imports `ampx_fixtures`)
- Rename: `scripts/ampx_fixtures/` → `scripts/ampx_fixtures/`
- Modify: `scripts/pyproject.toml`, regenerate `scripts/uv.lock`

**Interfaces:**
- Consumes: `AmpX.xcodeproj`, scheme `AmpX`, product `AmpX.app`
- Produces: scripts that build/launch/test/screenshot AmpX; fixture package import `ampx_fixtures`

- [ ] **Step 1: Point shell scripts at AmpX**

In `build.sh`, `create-dmg.sh`:

```bash
PROJECT_NAME="AmpX"
```

Replace user-facing echo/`osascript`/`killall`/`pkill` strings that target application name `Winamp` with `AmpX`. Keep the script logic identical.

In `bump-version.sh`:

```bash
PROJECT_FILE="${PROJECT_DIR}/AmpX.xcodeproj/project.pbxproj"
```

In `scripts/run-tests.sh`:

```bash
    -project AmpX.xcodeproj \
    -scheme AmpX \
```

In `scripts/shoot.sh`, replace every `Winamp` project/scheme/app/window-owner match with `AmpX`, and land shots at `/tmp/ampx_shot*.png` (update the header comment too). Critical window match:

```swift
for w in list where (w[kCGWindowOwnerName as String] as? String ?? "").contains("AmpX") {
```

Verify:

```bash
rg -n 'Winamp|winamp' build.sh bump-version.sh create-dmg.sh scripts/run-tests.sh scripts/shoot.sh || echo 'OK: shell scripts clean'
```

- [ ] **Step 2: Rename fixtures package**

```bash
git mv scripts/ampx_fixtures scripts/ampx_fixtures
```

Update `scripts/ampx_fixtures/generate.py` module docstring and any internal references from Winamp → AmpX (product name only).

Replace `scripts/pyproject.toml` with:

```toml
[project]
name = "ampx-test-fixtures"
version = "0.1.0"
description = "Generate binary test fixtures for AmpX"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
generate-fixtures = "ampx_fixtures.generate:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["ampx_fixtures"]
```

Regenerate the lockfile:

```bash
cd scripts && uv lock && uv sync
```

Check `scripts/generate-fixtures.sh` (and any other script) for `ampx_fixtures` / `winamp-test-fixtures` and update.

- [ ] **Step 3: Run fixtures + full suite**

```bash
./scripts/run-tests.sh
```

Expected: PASS under scheme `AmpX`.

- [ ] **Step 4: Do not commit yet** — docs still say Winamp (Task 5)

---

### Task 5: Docs, tagline, clean-break RELEASE note

**Files:**
- Modify: `README.md`, `AGENTS.md`, `CLAUDE.md`, `USAGE.md`, `BUILDING.md`, `RELEASE.md`, `CHANGES.md`
- Modify: `docs/**` where the text means *this* repository/app (not historical Winamp 2.x / Webamp / upstream)
- Leave alone: `LICENSE` upstream copyright lines; `docs/WEBAMP_REFERENCE.md` title/purpose (Webamp geometry reference); ENTHEA manual content that is about ENTHEA

**Interfaces:**
- Consumes: locked identity from the spec
- Produces: README that leads with AmpX + tagline; RELEASE documents clean break

- [ ] **Step 1: Rewrite README lead**

`README.md` should open approximately:

```markdown
# AmpX

Modern audio player. Classic spirit.

A native macOS music player with the compact floating-window workflow — playlist, EQ, visualizer — built for local libraries (MP3, FLAC, WAV, …).

> **This is a personal fork** of [`mbrukman/winamp-macos`](https://github.com/mbrukman/winamp-macos) (originally by Matt Greenwood, MIT licensed), itself a tribute to the original Winamp by Nullsoft.
> Active development continues at [`ratovarius/ampx`](https://github.com/ratovarius/ampx).
```

Update install/build bullets to `AmpX.xcodeproj`, scheme `AmpX`, `Tests/AmpXTests`. Keep the Webamp geometry attribution paragraph (it correctly says “Classic Winamp 2.x layout”).

- [ ] **Step 2: Update AGENTS.md / CLAUDE.md / USAGE.md / BUILDING.md**

- Product framing → AmpX + tagline / classic spirit
- Module map: `AmpXApp`, `AmpXPanel*`, `AmpXSkinSprites`, etc.
- Build commands: `AmpX.xcodeproj`, scheme `AmpX`
- Keep “Winamp UX spirit” / “Winamp 2.x skin UI” where that means the aesthetic lineage

- [ ] **Step 3: RELEASE.md clean-break note**

Add a short section (top or under the next version heading):

```markdown
## AmpX identity

This release renames the app to **AmpX** (`com.ampx.macos`). macOS treats it as a new app: preferences, playlist state, and folder bookmarks from builds that used `com.ampx.macos` are **not** imported. Both apps may coexist on disk. Re-add music folders / playlists in AmpX as needed.
```

- [ ] **Step 4: CHANGES.md entry**

Add a line under an AmpX / unreleased heading noting the rename and clean break (no behaviour change intended beyond identity).

- [ ] **Step 5: Sweep `docs/` project references**

```bash
rg -n 'Winamp\.xcodeproj|scheme AmpX|com\.winamp\.macos|Tests/AmpXTests|ratovarius/ampx|AmpXApp|ampx_fixtures' docs README.md AGENTS.md BUILDING.md USAGE.md RELEASE.md CHANGES.md || echo 'OK: doc anchors updated'
```

Update remaining hits that mean *this* app. Do **not** rewrite historical design-doc titles that say “Winamp” only as UX context unless they also contain broken paths (`AmpX.xcodeproj`, etc.).

- [ ] **Step 6: Do not commit yet** — verify build artifacts first (Task 6)

---

### Task 6: Verify build, tests, shoot; single rename commit (when user asks)

**Files:**
- None new — verification only

**Interfaces:**
- Consumes: Tasks 2–5 complete tree
- Produces: evidence the rename is behaviour-neutral

- [ ] **Step 1: Release build**

```bash
./build.sh --release
```

Expected: builds `AmpX.app`; no `Winamp.app` path in the success output.

- [ ] **Step 2: Full tests**

```bash
./scripts/run-tests.sh
```

Expected: PASS.

- [ ] **Step 3: Screenshot smoke**

```bash
./scripts/shoot.sh --no-build
# or ./scripts/shoot.sh if app not already running from a prior launch
ls -la /tmp/ampx_shot*.png
```

Expected: at least one non-empty `/tmp/ampx_shot0.png`. If “no AmpX windows found”, `shoot.sh` still matches the wrong owner name — fix Task 4.

- [ ] **Step 4: Final leftover scan (exclude historical / third-party)**

```bash
rg -n 'com\.winamp\.macos|Winamp\.xcodeproj|Tests/AmpXTests|ampx_fixtures|\bWinampApp\b|PRODUCT_NAME.*Winamp' \
  --glob '!.git/**' --glob '!.build/**' --glob '!.worktrees/**' --glob '!Reamp.app/**' \
  --glob '!docs/enthea-manual/shots/**' || echo 'OK: no stale build anchors'
```

Expected: `OK` (or only intentional historical prose).

- [ ] **Step 5: Commit only when the user explicitly asks**

Suggested message when asked:

```bash
git add -A
# carefully unstage Reamp.app / .worktrees / unrelated untracked docs if present
git commit -m "$(cat <<'EOF'
Rename project identity to AmpX.

Mechanical Winamp→AmpX rename for types, Xcode/SPM, scripts, and docs. New bundle ID com.ampx.macos with a clean break on prefs (no migration).
EOF
)"
```

---

### Task 7: GitHub repo rename + remote URLs

**Files:**
- Modify: any remaining `ratovarius/ampx` URLs if Task 5 missed them
- Remote: `origin`

**Interfaces:**
- Consumes: GitHub repo currently `ratovarius/ampx`
- Produces: `ratovarius/ampx` with updated `origin`

- [ ] **Step 1: Rename on GitHub**

```bash
gh repo rename ampx --yes
git remote -v
```

Expected: `origin` shows `https://github.com/ratovarius/ampx.git` (or SSH equivalent). If `gh` does not rewrite the local remote automatically:

```bash
git remote set-url origin https://github.com/ratovarius/ampx.git
```

Leave `upstream` as `https://github.com/mbrukman/winamp-macos.git`.

- [ ] **Step 2: Push develop (only if user asks to push)**

```bash
git push -u origin HEAD
```

- [ ] **Step 3: Confirm GitHub UI**

```bash
gh repo view ratovarius/ampx --json name,url,description
```

Optional: set description to `AmpX — Modern audio player. Classic spirit.` via `gh repo edit -d "..."`.

---

### Task 8: Local folder rename (last; user-gated)

**Files:**
- None in-repo — filesystem parent directory

**Interfaces:**
- Consumes: user ready to reopen Cursor at the new path
- Produces: `~/ampx` working tree

- [ ] **Step 1: Confirm with the user that Cursor can close/reopen the workspace**

Do not move the directory while an agent session still depends on `/Users/santiagorodriguez/winamp-macos`.

- [ ] **Step 2: Rename**

```bash
cd /Users/santiagorodriguez
mv winamp-macos ampx
```

- [ ] **Step 3: Reopen Cursor at `/Users/santiagorodriguez/ampx` and verify**

```bash
cd /Users/santiagorodriguez/ampx
git remote -v
./scripts/run-tests.sh
```

Expected: remotes correct; suite still PASS.

---

## Spec coverage checklist

| Spec requirement | Task |
|---|---|
| Name AmpX + tagline | 5 |
| Repo/folder `ampx` | 7, 8 |
| Bundle `com.ampx.macos` | 3 |
| Type prefix `AmpX*` | 2 |
| ENTHEA unchanged | Global + 2/5 exclusions |
| No migration / clean break | Global + RELEASE in 5 |
| Big-bang mechanical rename | 2–5, single commit in 6 |
| Light clearance recorded | Already in spec (no task) |
| Build scripts / shoot / fixtures | 4 |
| Attribution retained | 5 |
| Visual skin deferred | Global non-goal |
| Folder rename last | 8 |
