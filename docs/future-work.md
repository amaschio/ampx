# Future work

Deferred ideas that are intentionally out of the current delivery path. Prefer linking a
superpowers plan/spec when one exists.

---

## ENTHEA: optional further Metal port (former Stage / Task 10)

**Status:** skip unless explicitly requested.  
**Spec / plan:** `docs/superpowers/specs/2026-08-02-enthea-visualizer-design.md`,
`docs/superpowers/plans/2026-08-02-enthea-visualizer.md` (Task 10).

### What it is

Rewrite more of ENTHEA’s visual modes (and eventually the panel body) as native **Metal**
shaders / plugins, so the Visualizer panel no longer depends on vendored WebGL in
`WKWebView`.

Stage 8 (ENTHEA-styled mini LCD) was **skipped** by product choice, so there is no
mini-LCD porting pattern to reuse; a Stage 10 effort would start from the existing
fullscreen / mini Metal stack and ENTHEA’s GLSL as reference.

### Benefits (honest)

| Claim | Reality |
|---|---|
| **Performance / power** | **Yes, the main win.** Drops the WebContent process, JS `evaluateJavaScript` audio IPC, and WebGL stack. Better for sustained battery use and Activity Monitor noise. At current panel sizes the WebKit path already holds ~60 fps with the 2.0 Mpx clamp — this is not “we can’t hit frame rate today.” |
| **Real-time / sync** | **Marginal.** Playback → features → viz is already real-time on the WebKit path. Metal might shave IPC jitter; it does not unlock a new class of audio locking unless you also port ENTHEA’s DSP (BPM, drops, etc.), which is a large separate chunk of work. |
| **Better visualizations** | **No.** Same modes, same look (or slightly worse if the port is incomplete). Quality comes from ENTHEA’s shaders and analysis, not from Metal vs WebGL. |

### Other reasons you might still want it

- **License / distribution:** escaping the vendored AGPL WebGL blob if the app is ever published or App Store–bound (`Resources/Enthea/VENDOR.md`).
- **Process model:** one fewer helper process; teardown is just releasing Metal views.
- **One graphics stack:** panel and mini LCD both Metal (today the panel is WebKit, mini stays Classic Metal).

### Cost / risk

- Large: ~29 mode branches in one uber-shader, plus analysis if you want feature parity.
- Easy to ship a thinner, less reactive viz if only the pretty fragment is ported and ENTHEA’s `updateAudio` chain is not.

**Do not start by default.** Pursue only if WebKit cost, battery, or distribution constraints justify the rewrite.
