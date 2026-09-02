(function () {
  // Kill ENTHEA's keyboard before anything else. Its global keydown binds space
  // (cycles visual mode) plus a b d f h j k m r t w = and 1–8. Space is play/pause
  // here; playlist hotkeys own several others.
  window.addEventListener(
    "keydown",
    function (e) {
      e.stopImmediatePropagation();
    },
    true
  );

  // Host-supplied backing scale (Task −1: 2.0 Mpx budget). Falls back to DPR≤2.
  if (typeof window.__winampBackingScale !== "number") {
    window.__winampBackingScale = Math.min(window.devicePixelRatio || 1, 2);
  }

  // Replace ENTHEA's resize so theater doesn't run at full Retina Mpx.
  if (typeof resize === "function") {
    resize = function () {
      const DPR = Math.min(
        typeof window.__winampBackingScale === "number"
          ? window.__winampBackingScale
          : window.devicePixelRatio || 1,
        2
      );
      const w = Math.floor(innerWidth * DPR);
      const h = Math.floor(innerHeight * DPR);
      canvas.width = w;
      canvas.height = h;
      canvas.style.width = innerWidth + "px";
      canvas.style.height = innerHeight + "px";
      allocScene(Math.max(2, Math.floor(w * 0.85)), Math.max(2, Math.floor(h * 0.85)));
      S.reseed = 2;
    };
  }

  // ---- Task 3: fake AnalyserNode fed by Swift (raw 512 bins + stereo PCM) ----
  const BINS = 512,
    WAVE = 2048;
  const bins = new Uint8Array(BINS);
  const waveL = new Float32Array(WAVE),
    waveR = new Float32Array(WAVE);
  const waveMono = new Float32Array(WAVE);

  function installFakeAnalyser(sampleRate) {
    if (typeof AUDIO !== "object" || typeof S !== "object") return;
    AUDIO.ctx = AUDIO.ctx || { sampleRate: sampleRate, currentTime: 0 };
    AUDIO.ctx.sampleRate = sampleRate;
    const mk = (src) => ({
      fftSize: WAVE,
      frequencyBinCount: BINS,
      smoothingTimeConstant: 0,
      getByteFrequencyData(out) {
        out.set(bins.subarray(0, out.length));
      },
      getFloatTimeDomainData(out) {
        out.set(src.subarray(0, out.length));
      },
    });
    AUDIO.analyser = mk(waveMono);
    AUDIO.anL = mk(waveL);
    AUDIO.anR = mk(waveR);
    AUDIO.data = new Uint8Array(BINS);
    AUDIO.wave = new Float32Array(WAVE);
    AUDIO.waveL = new Float32Array(WAVE);
    AUDIO.waveR = new Float32Array(WAVE);
    AUDIO._winampShim = true;
    // Prefer file when a native timeline is present (useTL); otherwise winamp.
    // Must not be 'system' — that arms the DRM-silence watchdog.
    S.audio.source = S.timeline ? "file" : "winamp";
  }

  function decodePush(blob) {
    const binStr = atob(blob);
    const bytes = new Uint8Array(binStr.length);
    for (let i = 0; i < binStr.length; i++) bytes[i] = binStr.charCodeAt(i);
    bins.set(bytes.subarray(0, BINS));
    const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    let o = BINS;
    for (let i = 0; i < WAVE; i++, o += 4) {
      waveL[i] = view.getFloat32(o, true);
    }
    for (let i = 0; i < WAVE; i++, o += 4) {
      waveR[i] = view.getFloat32(o, true);
    }
    for (let i = 0; i < WAVE; i++) {
      waveMono[i] = (waveL[i] + waveR[i]) * 0.5;
    }
  }

  function clamp01(v) {
    return Math.max(0, Math.min(1, v));
  }

  function applyCoverArtFromImage(img) {
    if (typeof gl === "undefined" || typeof imgTexture === "undefined") return;
    gl.bindTexture(gl.TEXTURE_2D, imgTexture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, img);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.generateMipmap(gl.TEXTURE_2D);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    const cv = document.createElement("canvas");
    cv.width = 6;
    cv.height = 1;
    const cx = cv.getContext("2d");
    cx.drawImage(img, 0, 0, 6, 1);
    const d = cx.getImageData(0, 0, 6, 1).data;
    const pal = [];
    for (let i = 0; i < 6; i++) {
      pal.push([
        Math.pow(d[i * 4] / 255, 2.2),
        Math.pow(d[i * 4 + 1] / 255, 2.2),
        Math.pow(d[i * 4 + 2] / 255, 2.2),
      ]);
    }
    if (typeof S === "object") {
      S.imgPal = pal;
      S._imgPalFlat = new Float32Array(pal.flat());
    }
    if (typeof setPalette === "function") setPalette(9);
    if (typeof setMode === "function") setMode(10, true);
  }

  let renderPaused = false;
  let renderLoopAlive = true;
  if (typeof frame === "function") {
    const origFrame = frame;
    frame = function () {
      if (renderPaused) {
        renderLoopAlive = false;
        return;
      }
      renderLoopAlive = true;
      origFrame();
    };
  }

  const api = {
    ready: false,
    hideChrome() {
      if (typeof setCollapsed === "function") setCollapsed(true);
      // Same class ENTHEA uses in fullscreen: hide title / hint / buttons.
      document.body.classList.add("immersive");
    },
    // Absolute mode index. Use stepMode(±1) for relative (avoids clashing with mode 1).
    setMode(i) {
      if (typeof setMode !== "function" || typeof MODES === "undefined") return;
      const n = MODES.length;
      const next = ((Number(i) % n) + n) % n;
      setMode(next, true);
    },
    stepMode(delta) {
      if (typeof S !== "object" || typeof MODES === "undefined") return;
      this.setMode(S.mode + (Number(delta) || 0));
    },
    setAutopilot(on) {
      const el = document.getElementById("tgJourney");
      if (el && el.classList.contains("on") !== !!on) el.click();
    },
    setDose(delta) {
      if (typeof setDose !== "function" || typeof S !== "object") return;
      setDose(clamp01(S.dose + Number(delta)));
    },
    fireDrop() {
      if (typeof fireDrop === "function") fireDrop(false);
    },
    reseed() {
      if (typeof S === "object") S.reseed = 2;
    },
    setSubstance(id) {
      if (typeof SUBSTANCES === "undefined" || typeof applySubstance !== "function") return;
      const key = String(id || "");
      const prof = SUBSTANCES.find(function (s) {
        return s.id === key;
      });
      if (!prof) return;
      // Visual signature only — do not beginTrip (no timed phase HUD).
      applySubstance(prof);
    },
    setBackingScale(scale) {
      window.__winampBackingScale = scale;
      if (typeof resize === "function") resize();
    },
    /** Task 7: 0 fps while stopped / occluded / minimized — resume kicks rAF. */
    setRenderPaused(paused) {
      renderPaused = !!paused;
      if (typeof S === "object" && S.audio) {
        if (renderPaused) S.audio.on = false;
      }
      if (!renderPaused && !renderLoopAlive && typeof frame === "function") {
        renderLoopAlive = true;
        requestAnimationFrame(frame);
      }
    },
    /** Task 7: album art → IMAGE WARP (data URL or raw base64 + mime). */
    setCoverArt(dataURL) {
      if (!dataURL || typeof dataURL !== "string") return;
      const img = new Image();
      img.onload = function () {
        applyCoverArtFromImage(img);
      };
      img.src = dataURL;
    },
    getStatus() {
      const el = document.getElementById("tgJourney");
      const mode = typeof S === "object" ? S.mode : 0;
      const name =
        typeof MODES !== "undefined" && MODES[mode] ? MODES[mode].name : "";
      return {
        ready: api.ready,
        mode: mode,
        name: name,
        autopilot: !!(el && el.classList.contains("on")),
        dose: typeof S === "object" ? S.dose : 0.45,
      };
    },
  };
  function ensureFileEl() {
    if (typeof AUDIO !== "object") return;
    if (!AUDIO.fileEl || typeof AUDIO.fileEl !== "object") {
      AUDIO.fileEl = { currentTime: 0, paused: true };
    }
  }

  window.winampEnthea = api;
  window.winampAudio = {
    push(blob, sampleRate, isPlaying) {
      if (typeof AUDIO !== "object" || typeof S !== "object") return;
      if (!AUDIO._winampShim) installFakeAnalyser(sampleRate || 44100);
      else if (AUDIO.ctx) AUDIO.ctx.sampleRate = sampleRate || AUDIO.ctx.sampleRate;
      try {
        decodePush(blob);
      } catch (e) {
        return;
      }
      // Pause → ENTHEA's updateAudio early-returns and envelopes decay.
      S.audio.on = !!isPlaying;
      // File path only while a native map is loaded; otherwise host analyser.
      S.audio.source = S.timeline ? "file" : "winamp";
    },
    setTimeline(tl) {
      if (typeof S !== "object" || typeof AUDIO !== "object") return;
      ensureFileEl();
      if (!tl) {
        S.timeline = null;
        S.audio.source = "winamp";
        return;
      }
      S.timeline = {
        dur: Number(tl.dur) || 0,
        drops: Array.isArray(tl.drops) ? tl.drops.map(Number) : [],
        sections: Array.isArray(tl.sections)
          ? tl.sections.map(function (s) {
              return { t: Number(s.t) || 0, energy: s.energy | 0 };
            })
          : [],
        fps: Number(tl.fps) || 0,
        _di: 0,
        _si: 0,
        _lastCt: 0,
        _cd: 0,
        _sx: 0,
      };
      S.audio.source = "file";
    },
    setPosition(seconds, paused) {
      if (typeof AUDIO !== "object") return;
      ensureFileEl();
      AUDIO.fileEl.currentTime = Number(seconds) || 0;
      AUDIO.fileEl.paused = !!paused;
    },
  };

  // Boot: hide ENTHEA's HTML chrome; keep flicker off (default in S).
  api.hideChrome();
  if (typeof S === "object" && S.flicker) {
    const el = document.getElementById("tgFlicker");
    if (el && el.classList.contains("on")) el.click();
  }
  if (typeof resize === "function") resize();

  api.ready = true;
})();
