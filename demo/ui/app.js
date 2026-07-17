(() => {
  const I18N = {
    en: {
      hero: "Trace Client (manual or automatic) → Kong → Vault HA in one view.",
      relatedUis: "Related UIs",
      language: "Language",
      autoApp: "Auto App",
      stopAuto: "Stop Auto",
      executionTree: "Execution Tree",
      runTrace: "Run Trace",
      actor: "Actor",
      manualClient: "Manual Client",
      manualClientDetail: "One request with Play",
      autoAppActor: "Auto App",
      autoAppActorDetail: "App apikey → /app Route only",
      actorClientShort: "Manual Client",
      actorAppShort: "Auto App",
      sceneSelection: "{actor} · {key} → {path}",
      appSceneSelection: "{actor} · {key} → /app{path}",
      scenes: "Scenes",
      sceneAppA: "app-a allowed",
      sceneAppB: "app-b allowed",
      sceneDeny: "cross ACL deny",
      sceneDenyDetail: "app-a key accesses app-b path → 403",
      sceneAppDenyDetail: "App key on Client Route → 403",
      sceneCache: "cache MISS → HIT",
      sceneCacheDetail: "Two identical GETs, X-Kong-Vault-Proxy-Cache",
      noRun: "No run yet",
      noRunDetail: "Choose a scene and press Play to trace Client → Kong → Vault.",
      liveTopology: "Live Topology",
      trafficThroughKong: "Traffic Through Kong",
      current: "Current",
      waiting: "Waiting",
      waitingDetail: "Press Play to activate the request path.",
      manual: "Manual",
      manualDetail: "A person sends GET with Play",
      autoDetail: "Fetches a secret periodically",
      request: "Request",
      response: "Response",
      idle: "idle",
      running: "running",
      done: "done",
      error: "error",
      clientToKong: "1. Client → Kong",
      entersGateway: "The request enters Kong Gateway.",
      clientRequest: "Client request",
      appRequest: "App request",
      kongKeyAuth: "2. Kong key-auth",
      identifyConsumer: "Identify the Consumer using apikey.",
      kongAcl: "3. Kong ACL",
      checkRouteAcl: "Check access to the Route path.",
      aclDenied: "ACL denied",
      aclDeny: "ACL deny",
      aclDenyDetail: "Route ACL blocked cross-access.",
      proxyStage: "4. kong-vault-proxy",
      proxyDetail: "Inject AppRole token and call Vault through Upstream RR.",
      appProxyDetail: "App Route passed; plugin authenticates to Vault with AppRole.",
      vaultRead: "Vault read",
      failure: "Failed",
      failureDetail: "expected {expected}, got {actual} — run ./demo/reauth.sh and retry",
      cachePath: "Cache path",
      cacheNoVault: "Vault upstream was not called.",
      vaultPeer: "Vault peer",
      unmappedPeer: "upstream={peer} (hostname not mapped)",
      cacheReplay: "5. Cache replay",
      cacheReplayDetail: "Repeat the same request to verify HIT.",
      cacheHit: "Cache HIT",
      cacheHitDetail: "Kong responds without calling Vault again.",
      complete: "Complete",
      cacheComplete: "MISS then HIT — kong-vault-proxy cache works.",
      cacheUnknown: "Cache not confirmed",
      routeComplete: "Path: {actor} → Kong → {vault} → Kong → {actor}",
      vaultReturned: "Vault secret was returned to the Client.",
      requestError: "Error",
      fetchFailed: "fetch failed: {message} (check CORS/proxy URL)",
    },
    ko: {
      hero: "Client(수동·자동) → Kong → Vault HA 경로를 한 화면에서 추적합니다.",
      relatedUis: "관련 UI",
      language: "언어",
      autoApp: "자동 앱",
      stopAuto: "자동 중지",
      executionTree: "실행 트리",
      runTrace: "실행 추적",
      actor: "호출 주체",
      manualClient: "수동 Client",
      manualClientDetail: "Play로 1회 요청",
      autoAppActor: "자동 App",
      autoAppActorDetail: "App apikey → /app Route만",
      actorClientShort: "수동 Client",
      actorAppShort: "자동 App",
      sceneSelection: "{actor} · {key} → {path}",
      appSceneSelection: "{actor} · {key} → /app{path}",
      scenes: "시나리오",
      sceneAppA: "app-a 허용",
      sceneAppB: "app-b 허용",
      sceneDeny: "교차 ACL 거부",
      sceneDenyDetail: "app-a 키로 app-b 경로 접근 → 403",
      sceneAppDenyDetail: "App 키로 Client Route 접근 → 403",
      sceneCache: "캐시 MISS → HIT",
      sceneCacheDetail: "동일 GET 2회, X-Kong-Vault-Proxy-Cache",
      noRun: "아직 실행 없음",
      noRunDetail: "시나리오를 고르고 Play 하면 Client → Kong → Vault hop이 기록됩니다.",
      liveTopology: "실시간 토폴로지",
      trafficThroughKong: "Kong 통과 트래픽",
      current: "현재",
      waiting: "대기",
      waitingDetail: "Play로 요청을 시작하면 Kong이 경로를 활성화합니다.",
      manual: "수동",
      manualDetail: "사람이 Play로 GET 요청",
      autoDetail: "주기적으로 secret 조회",
      request: "요청",
      response: "응답",
      idle: "대기",
      running: "실행 중",
      done: "완료",
      error: "오류",
      clientToKong: "1. Client → Kong",
      entersGateway: "요청이 Kong Gateway로 진입합니다.",
      clientRequest: "Client 요청",
      appRequest: "App 요청",
      kongKeyAuth: "2. Kong key-auth",
      identifyConsumer: "apikey로 Consumer를 식별합니다.",
      kongAcl: "3. Kong ACL",
      checkRouteAcl: "Route 경로 접근 권한을 검사합니다.",
      aclDenied: "ACL 거부",
      aclDeny: "ACL 거부",
      aclDenyDetail: "Route ACL이 교차 접근을 차단했습니다.",
      proxyStage: "4. kong-vault-proxy",
      proxyDetail: "AppRole 토큰을 주입하고 Upstream RR로 Vault를 호출합니다.",
      appProxyDetail: "App Route 통과 후 플러그인이 AppRole로 Vault에 인증합니다.",
      vaultRead: "Vault 조회",
      failure: "실패",
      failureDetail: "예상 {expected}, 실제 {actual} — ./demo/reauth.sh 후 재시도",
      cachePath: "캐시 경로",
      cacheNoVault: "Vault upstream을 호출하지 않았습니다.",
      vaultPeer: "Vault 대상",
      unmappedPeer: "upstream={peer} (호스트명 매핑 없음)",
      cacheReplay: "5. 캐시 재요청",
      cacheReplayDetail: "동일 요청으로 HIT를 확인합니다.",
      cacheHit: "캐시 HIT",
      cacheHitDetail: "Vault를 다시 호출하지 않고 Kong이 응답합니다.",
      complete: "완료",
      cacheComplete: "MISS 다음 HIT — kong-vault-proxy 캐시가 동작합니다.",
      cacheUnknown: "캐시 미확인",
      routeComplete: "경로: {actor} → Kong → {vault} → Kong → {actor}",
      vaultReturned: "Vault secret이 Client로 반환되었습니다.",
      requestError: "오류",
      fetchFailed: "fetch 실패: {message} (CORS/proxy URL 확인)",
    },
  };

  const APP_KEY = "vault-app-key";

  const SCENES = {
    "app-a": {
      titleKey: "sceneAppA",
      path: "/secret/data/app-a/demo",
      key: "vault-app-a-key",
      expect: 200,
    },
    "app-b": {
      titleKey: "sceneAppB",
      path: "/secret/data/app-b/demo",
      key: "vault-app-b-key",
      expect: 200,
    },
    deny: {
      titleKey: "sceneDeny",
      path: "/secret/data/app-b/demo",
      key: "vault-app-a-key",
      expect: 403,
    },
    cache: {
      titleKey: "sceneCache",
      path: "/secret/data/app-a/demo",
      key: "vault-app-a-key",
      expect: 200,
      twice: true,
    },
  };

  const els = {
    language: document.getElementById("language"),
    proxyUrl: document.getElementById("proxy-url"),
    play: document.getElementById("btn-play"),
    auto: document.getElementById("btn-auto"),
    reset: document.getElementById("btn-reset"),
    runState: document.getElementById("run-state"),
    stageTitle: document.getElementById("stage-title"),
    stageDetail: document.getElementById("stage-detail"),
    traceTree: document.getElementById("trace-tree"),
    detailRequest: document.getElementById("detail-request"),
    detailResponse: document.getElementById("detail-response"),
    topology: document.getElementById("topology"),
  };

  let sceneId = "app-a";
  let actorId = "client";
  let language = localStorage.getItem("kong-vault-proxy-language") || "en";
  let busy = false;
  let autoTimer = null;
  let autoToggle = false;
  let vaultMap = {};

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  function t(key, values = {}) {
    let text = I18N[language][key] || I18N.en[key] || key;
    Object.entries(values).forEach(([name, value]) => {
      text = text.replaceAll(`{${name}}`, String(value));
    });
    return text;
  }

  function applyLanguage() {
    document.documentElement.lang = language;
    els.language.value = language;
    document.querySelectorAll("[data-i18n]").forEach((node) => {
      node.textContent = t(node.dataset.i18n);
    });
    document.querySelectorAll("[data-i18n-aria-label]").forEach((node) => {
      node.setAttribute("aria-label", t(node.dataset.i18nAriaLabel));
    });
    setRunState(els.runState.dataset.state || "idle");
    selectActor(actorId);
    els.auto.textContent = t(autoToggle ? "stopAuto" : "autoApp");
  }

  function setRunState(state) {
    els.runState.dataset.state = state;
    els.runState.textContent = t(state);
    els.runState.className = "run-state " + (state === "idle" ? "" : state);
  }

  function setStage(title, detail) {
    els.stageTitle.textContent = title;
    els.stageDetail.textContent = detail;
  }

  function clearNodes() {
    els.topology.querySelectorAll(".node").forEach((n) => {
      n.classList.remove("active", "complete", "error");
    });
    els.topology.querySelectorAll(".kong-chips li").forEach((c) => {
      c.classList.remove("active", "deny");
    });
  }

  function clearLines() {
    els.topology.querySelectorAll(".topology-lines path").forEach((p) => {
      p.classList.remove("active", "error");
    });
  }

  function clearTopology() {
    clearNodes();
    clearLines();
  }

  function setNodeState(ids, state) {
    ids.forEach((id) => {
      const n = els.topology.querySelector(`[data-node="${id}"]`);
      if (!n) return;
      n.classList.remove("active", "complete", "error");
      if (state) n.classList.add(state);
    });
  }

  function setChips(ids, mode = "active") {
    els.topology.querySelectorAll(".kong-chips li").forEach((c) => {
      c.classList.remove("active", "deny");
    });
    ids.forEach((id) => {
      const c = els.topology.querySelector(`[data-chip="${id}"]`);
      if (c) c.classList.add(mode === "deny" && id === "acl" ? "deny" : "active");
    });
  }

  function setLines(ids, mode = "active") {
    clearLines();
    ids.filter(Boolean).forEach((id) => {
      const p = document.getElementById(id);
      if (p) p.classList.add(mode);
    });
  }

  /** Active edges for the hop actually taken. */
  function outLine(actor) {
    return actor === "app" ? "line-app-kong" : "line-client-kong";
  }

  function backLine(actor) {
    return actor === "app" ? "line-kong-app" : "line-kong-client";
  }

  function vaultOutLine(vaultNode) {
    if (!vaultNode) return null;
    return `line-kong-${vaultNode.replace("-", "")}`;
  }

  function vaultBackLine(vaultNode) {
    if (!vaultNode) return null;
    // vault-1 → line-vault1-kong
    return `line-${vaultNode.replace("-", "")}-kong`;
  }

  /**
   * Paint only the path segments for this phase.
   * phase: to-kong | at-kong | to-vault | from-vault | cache | deny | error
   */
  function paintPath({ actor, vault, phase, chips = [], error = false }) {
    const mode = error ? "error" : "active";
    const out = outLine(actor);
    const back = backLine(actor);
    const vOut = vaultOutLine(vault);
    const vBack = vaultBackLine(vault);

    if (phase === "to-kong") {
      setLines([out], mode);
      setNodeState([actor], error ? "error" : "active");
      setNodeState(["kong", "vault-1", "vault-2", "vault-3"], null);
      setChips([]);
      return;
    }

    if (phase === "at-kong") {
      setLines([out], mode);
      setNodeState([actor, "kong"], error ? "error" : "active");
      setNodeState(["vault-1", "vault-2", "vault-3"], null);
      // ponytail: ACL deny 스타일은 phase=deny 전용. 다른 오류(502 등)에 ACL deny로 보이면 안 됨
      setChips(chips, "active");
      return;
    }

    if (phase === "to-vault") {
      setLines([out, vOut].filter(Boolean), mode);
      setNodeState([actor, "kong"], "active");
      setNodeState(["vault-1", "vault-2", "vault-3"], null);
      if (vault) setNodeState([vault], error ? "error" : "active");
      setChips(chips);
      return;
    }

    if (phase === "from-vault") {
      // full round-trip: actor→kong→vault and vault→kong→actor
      setLines([out, vOut, vBack, back].filter(Boolean), mode);
      setNodeState([actor, "kong"], "complete");
      setNodeState(["vault-1", "vault-2", "vault-3"], null);
      if (vault) setNodeState([vault], error ? "error" : "complete");
      setChips(chips);
      return;
    }

    if (phase === "cache") {
      // cache HIT: no vault edge — actor↔kong only
      setLines([out, back], mode);
      setNodeState([actor, "kong"], "complete");
      setNodeState(["vault-1", "vault-2", "vault-3"], null);
      setChips(chips);
      return;
    }

    if (phase === "deny") {
      setLines([out], "error");
      setNodeState([actor, "kong"], "error");
      setNodeState(["vault-1", "vault-2", "vault-3"], null);
      setChips(chips, "deny");
    }
  }

  async function loadVaultMap() {
    try {
      const res = await fetch("./vault-map.json", { cache: "no-store" });
      if (res.ok) vaultMap = await res.json();
    } catch {
      vaultMap = {};
    }
  }

  function vaultNodeFromPeer(peer) {
    if (!peer || peer === "-" || peer === "cache") return null;
    const s = String(peer);
    const named = s.match(/vault-([123])/i);
    if (named) return `vault-${named[1]}`;
    if (vaultMap[s]) return vaultMap[s];
    const ip = s.split(":")[0];
    if (vaultMap[ip]) return vaultMap[ip];
    return null;
  }

  function clearTrace() {
    els.traceTree.innerHTML = "";
  }

  function addTrace(title, detail, kind = "") {
    if (els.traceTree.querySelector(".trace-empty")) {
      els.traceTree.innerHTML = "";
    }
    els.traceTree.querySelectorAll(".trace-item.active").forEach((n) => {
      n.classList.remove("active");
    });
    const item = document.createElement("div");
    item.className = "trace-item active" + (kind ? " " + kind : "");
    const when = new Date().toLocaleTimeString();
    item.innerHTML = `<span class="when">${when}</span><strong>${title}</strong><p>${detail}</p>`;
    els.traceTree.prepend(item);
  }

  function selectActor(id) {
    actorId = id === "app" ? "app" : "client";
    document.querySelectorAll(".actor").forEach((button) => {
      const active = button.dataset.actor === actorId;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    const denyDetail = document.querySelector('[data-scene="deny"] span');
    if (denyDetail) {
      denyDetail.textContent = t(actorId === "app" ? "sceneAppDenyDetail" : "sceneDenyDetail");
    }
    selectScene(sceneId);
  }

  function selectScene(id) {
    sceneId = id;
    document.querySelectorAll(".scene").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.scene === id);
    });
    const scene = SCENES[id];
    const key = actorId === "app" ? APP_KEY : scene.key;
    setStage(
      t(scene.titleKey),
      actorId === "app"
        ? t("appSceneSelection", {
            actor: t("actorAppShort"),
            key,
            path: scene.path,
          })
        : t("sceneSelection", {
            actor: t("actorClientShort"),
            key,
            path: scene.path,
          })
    );
  }

  function requestUrl(scene) {
    const base = els.proxyUrl.value.replace(/\/$/, "");
    if (actorId === "app") {
      // App key is only allowed on /app; deny scene uses Client Route to show ACL block.
      if (scene.expect === 403) {
        return {
          url: `${base}${scene.path}?apikey=${encodeURIComponent(APP_KEY)}`,
          key: APP_KEY,
          auth: "query apikey (App on Client Route)",
        };
      }
      return {
        url: `${base}/app${scene.path}?apikey=${encodeURIComponent(APP_KEY)}`,
        key: APP_KEY,
        auth: "query apikey (App Route)",
      };
    }
    return {
      url: `${base}${scene.path}?apikey=${encodeURIComponent(scene.key)}`,
      key: scene.key,
      auth: "query apikey",
    };
  }

  async function requestOnce(scene, label) {
    const req = requestUrl(scene);
    els.detailRequest.textContent = JSON.stringify({
      method: "GET",
      url: req.url,
      auth: req.auth,
    }, null, 2);

    const started = performance.now();
    let res;
    let bodyText = "";
    try {
      res = await fetch(req.url, { method: "GET" });
      bodyText = await res.text();
    } catch (err) {
      throw new Error(t("fetchFailed", { message: err.message }));
    }
    const ms = Math.round(performance.now() - started);
    const cache = res.headers.get("X-Kong-Vault-Proxy-Cache") || "-";
    const vault = res.headers.get("X-Kong-Vault-Proxy-Vault") || "-";
    let bodyJson;
    try {
      bodyJson = JSON.parse(bodyText);
    } catch {
      bodyJson = bodyText;
    }

    els.detailResponse.textContent = JSON.stringify({
      status: res.status,
      cache,
      vault,
      ms,
      body: bodyJson,
    }, null, 2);

    addTrace(
      `${label}: HTTP ${res.status}`,
      `vault=${vault}, cache=${cache}, ${ms}ms`,
      res.status >= 400 ? "error" : ""
    );

    return { status: res.status, cache, vault, ms, bodyJson };
  }

  async function playScene() {
    if (busy) return;
    busy = true;
    setRunState("running");
    clearTopology();
    clearTrace();

    const scene = { ...SCENES[sceneId] };
    const actor = actorId;
    const proxyChips = ["auth", "acl", "proxy"];
    const cacheChips = [...proxyChips, "cache"];
    const req = requestUrl(scene);

    try {
      setStage(t("clientToKong"), t("entersGateway"));
      addTrace(
        t(actor === "app" ? "appRequest" : "clientRequest"),
        `${req.key} GET ${req.url.replace(els.proxyUrl.value.replace(/\/$/, ""), "")}`
      );
      paintPath({ actor, phase: "to-kong" });
      await sleep(350);

      setStage(t("kongKeyAuth"), t("identifyConsumer"));
      paintPath({ actor, phase: "at-kong", chips: ["auth"] });
      await sleep(280);

      setStage(t("kongAcl"), t("checkRouteAcl"));
      paintPath({ actor, phase: "at-kong", chips: ["auth", "acl"] });
      await sleep(280);

      if (scene.expect === 403) {
        const result = await requestOnce(scene, t("aclDenied"));
        paintPath({
          actor,
          phase: "deny",
          chips: ["auth", "acl"],
        });
        setStage(t("aclDeny"), t("aclDenyDetail"));
        setRunState(result.status === 403 ? "done" : "error");
        busy = false;
        return;
      }

      setStage(
        t("proxyStage"),
        t(actor === "app" ? "appProxyDetail" : "proxyDetail")
      );
      paintPath({ actor, phase: "at-kong", chips: proxyChips });
      await sleep(200);

      const first = await requestOnce(scene, scene.twice ? "MISS?" : t("vaultRead"));
      const vaultNode = vaultNodeFromPeer(first.vault);
      const hitCache =
        (first.cache || "").toUpperCase() === "HIT" || first.vault === "cache";

      if (first.status !== scene.expect) {
        paintPath({
          actor,
          vault: vaultNode,
          phase: vaultNode ? "to-vault" : "at-kong",
          chips: proxyChips,
          error: true,
        });
        if (first.status === 403) {
          const aclChip = els.topology.querySelector('[data-chip="acl"]');
          if (aclChip) {
            aclChip.classList.remove("active");
            aclChip.classList.add("deny");
          }
        }
        setStage(
          t("failure"),
          t("failureDetail", { expected: scene.expect, actual: first.status })
        );
        setRunState("error");
        busy = false;
        return;
      }

      if (hitCache) {
        paintPath({
          actor,
          phase: "cache",
          chips: cacheChips,
        });
        addTrace(t("cachePath"), t("cacheNoVault"));
      } else {
        paintPath({
          actor,
          vault: vaultNode,
          phase: "to-vault",
          chips: proxyChips,
        });
        await sleep(280);
        paintPath({
          actor,
          vault: vaultNode,
          phase: "from-vault",
          chips: cacheChips,
        });
        if (!vaultNode) {
          addTrace(t("vaultPeer"), t("unmappedPeer", { peer: first.vault }), "error");
        }
      }

      if (scene.twice) {
        setStage(t("cacheReplay"), t("cacheReplayDetail"));
        await sleep(400);
        paintPath({
          actor,
          phase: "at-kong",
          chips: cacheChips,
        });
        const second = await requestOnce(scene, "HIT?");
        if ((second.cache || "").toUpperCase() === "HIT" || second.vault === "cache") {
          addTrace(t("cacheHit"), t("cacheHitDetail"));
          paintPath({
            actor,
            phase: "cache",
            chips: cacheChips,
          });
          setStage(t("complete"), t("cacheComplete"));
        } else {
          const v2 = vaultNodeFromPeer(second.vault);
          paintPath({
            actor,
            vault: v2,
            phase: "from-vault",
            chips: proxyChips,
          });
          setStage(t("cacheUnknown"), `cache=${second.cache}, vault=${second.vault}`);
        }
      } else {
        setStage(
          t("complete"),
          vaultNode
            ? t("routeComplete", { actor, vault: vaultNode })
            : t("vaultReturned")
        );
      }

      setRunState("done");
    } catch (err) {
      addTrace(t("requestError"), err.message, "error");
      paintPath({ actor, phase: "to-kong", error: true });
      setStage(t("requestError"), err.message);
      setRunState("error");
    } finally {
      busy = false;
    }
  }

  function stopAuto() {
    autoToggle = false;
    if (autoTimer) {
      clearInterval(autoTimer);
      autoTimer = null;
    }
    els.auto.textContent = t("autoApp");
  }

  function startAuto() {
    autoToggle = true;
    els.auto.textContent = t("stopAuto");
    selectActor("app");
    const cycle = ["app-a", "app-b", "cache"];
    let i = 0;
    const tick = async () => {
      if (!autoToggle || busy) return;
      selectScene(cycle[i % cycle.length]);
      i += 1;
      await playScene();
    };
    tick();
    autoTimer = setInterval(tick, 8000);
  }

  document.querySelectorAll(".scene").forEach((btn) => {
    btn.addEventListener("click", () => selectScene(btn.dataset.scene));
  });

  document.querySelectorAll(".actor").forEach((button) => {
    button.addEventListener("click", () => {
      stopAuto();
      selectActor(button.dataset.actor);
    });
  });
  els.language.addEventListener("change", () => {
    language = els.language.value;
    localStorage.setItem("kong-vault-proxy-language", language);
    applyLanguage();
  });
  els.play.addEventListener("click", () => playScene());
  els.auto.addEventListener("click", () => {
    if (autoToggle) stopAuto();
    else startAuto();
  });
  els.reset.addEventListener("click", () => {
    stopAuto();
    clearTopology();
    clearTrace();
    els.traceTree.innerHTML = `
      <div class="trace-empty">
        <h3>${t("noRun")}</h3>
        <p>${t("noRunDetail")}</p>
      </div>`;
    els.detailRequest.textContent = "-";
    els.detailResponse.textContent = "-";
    setRunState("idle");
    selectScene(sceneId);
  });

  selectActor("client");
  applyLanguage();
  loadVaultMap();
})();
