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
    // Must not be 'system' — that arms the DRM-silence watchdog.
    S.audio.source = "winamp";
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

  const api = {
    ready: false,
    hideChrome() {
      if (typeof setCollapsed === "function") setCollapsed(true);
      // Same class ENTHEA uses in fullscreen: hide title / hint / buttons.
      document.body.classList.add("immersive");
    },
    setMode(i) {
      if (typeof setMode === "function") setMode(i, true);
    },
    setAutopilot(on) {
      const el = document.getElementById("tgJourney");
      if (el && el.classList.contains("on") !== !!on) el.click();
    },
    setDose(/* delta */) {
      /* wired in Task 4 */
    },
    fireDrop() {
      if (typeof fireDrop === "function") fireDrop(false);
    },
    reseed() {
      if (typeof S === "object") S.reseed = 2;
    },
    setSubstance(/* id */) {
      /* wired in Task 9 */
    },
    setBackingScale(scale) {
      window.__winampBackingScale = scale;
      if (typeof resize === "function") resize();
    },
  };
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
    },
    setTimeline() {},
    setPosition() {},
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
