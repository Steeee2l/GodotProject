(() => {
    const dial = document.getElementById("frequencyDial");
    if (!dial) return;

    const cases = {
        subway: {
            title:"CASE 07 · 끊어진 지하 신호", frequency:98.7, location:"jongno3", truth:"real", threat:"high",
            objective:"보라색 노선과 얕은 배수음이 겹치는 장소", reward:"구조묘 3 · 지하 통행증", risk:"실패 시: 지하 매복 +1",
            rough:"“…치직… 지하… 보라색… 안쪽에… 발소리…”",
            clear:"“보라색 노선 표지… 환승 안내가 들려요. 셔터 안쪽에 셋이 있고, 바깥에 무장한 발소리가…”",
            transit:"보라색 노선 표지, 다중 환승 안내음", voice:"구조자 3명, 외부에 무장 인원",
            kits:["filter","battery"], effects:["B-4","매복 방향","정전 1회 무효","구조묘 3"]
        },
        rooftop: {
            title:"CASE 11 · 약국 옥상 섬광", frequency:103.2, location:"dongdaemun", truth:"real", threat:"medium",
            objective:"헬기장 경고음과 대형 환풍기가 함께 들리는 옥상", reward:"고급 의료품 · 약사 주민", risk:"실패 시: 독성 구역 확대",
            rough:"“…빨간 불… 옥상… 아이가… 바람이 너무…”",
            clear:"“십자가 간판 아래 옥상이에요. 환풍기가 세 번 돌면 붉은 경고등이 켜져요. 아이 한 명이 열이 심해요.”",
            transit:"대형 환풍기 3회 회전, 고가도로 소음", voice:"성인 2명과 환자 1명, 응급 해열 필요",
            kits:["medkit","battery"], effects:["D-3","저격수 표시","독성 40%↓","약사 주민"]
        },
        river: {
            title:"CASE 14 · 남산 중계기의 반복음", frequency:91.4, location:"namsan", truth:"trap", threat:"high",
            objective:"17초마다 같은 문장이 반복되는 고지대 중계 신호", reward:"군용 송신기 · 암호 키", risk:"실패 시: 추적조 난입",
            rough:"“…여기는 안전… 혼자… 서둘러… 안전…”",
            clear:"“여기는 안전합니다. 혼자 오십시오.” 같은 숨소리까지 정확히 17초마다 반복된다. 뒤쪽에서 장전음이 한 번 들린다.",
            transit:"바람 속 케이블 진동, 도로 소음 없음", voice:"호흡과 억양까지 동일한 녹음 신호",
            kits:["armor","battery"], effects:["A-7","함정 사전 탐지","증원 30초 지연","암호 키"]
        }
    };

    const state = { caseId:"subway", cleaned:false, captured:false, location:"", truth:"", threat:"", kits:new Set(), power:3, timer:240, timerId:null };
    const frequencyValue = document.getElementById("frequencyValue");
    const signalQuality = document.getElementById("signalQuality");
    const signalState = document.getElementById("signalState");
    const waveNoise = document.getElementById("waveNoise");
    const transcript = document.querySelector("#radioTranscript p");
    const confidenceValue = document.getElementById("confidenceValue");
    const confidenceBar = document.getElementById("confidenceBar");
    const operatorLine = document.getElementById("operatorLine");
    const powerCount = document.getElementById("powerCount");
    const raidPreview = document.getElementById("raidPreview");
    const clock = document.getElementById("opsClock");

    const currentCase = () => cases[state.caseId];
    const quality = () => Math.max(4, Math.round(100 - Math.abs(Number(dial.value) - currentCase().frequency) * 24 + (state.cleaned ? 16 : 0)));
    const say = text => { if (operatorLine) operatorLine.textContent = `“${text}”`; };

    function startTimer() {
        if (state.timerId) return;
        state.timerId = window.setInterval(() => {
            if (!document.getElementById("operations")?.classList.contains("active")) return;
            state.timer = Math.max(0, state.timer - 1);
            const minutes = Math.floor(state.timer / 60);
            clock.textContent = `${String(minutes).padStart(2,"0")}:${String(state.timer % 60).padStart(2,"0")}`;
            clock.classList.toggle("urgent", state.timer <= 60);
            if (state.timer === 60) say("1분 남았어. 완벽한 답보다 쓸모 있는 브리핑이 먼저야.");
            if (state.timer === 0) window.clearInterval(state.timerId);
        }, 1000);
    }

    function updateRadio() {
        startTimer();
        const q = Math.min(100, quality());
        const info = currentCase();
        frequencyValue.textContent = Number(dial.value).toFixed(1);
        signalQuality.textContent = `SNR ${String(q).padStart(2,"0")}%`;
        waveNoise.style.setProperty("--noise", String(Math.max(.12, 1 - q / 105)));
        signalState.textContent = q > 82 ? "음성 확보" : q > 48 ? "불완전 수신" : "신호 탐색 중";
        transcript.textContent = q > 82 ? (state.cleaned ? info.clear : info.rough) : q > 48 ? info.rough : "“…치직… 누구든 듣고 있으면… 들리나요…”";
        if (q > 82) say("잡았다. 이제 말보다 배경에서 반복되는 소리를 들어봐.");
        updateConfidence();
    }

    function updateConfidence() {
        let value = 12;
        if (quality() > 80) value += 18;
        if (state.cleaned) value += 14;
        if (state.captured) value += 12;
        if (state.location) value += 12;
        if (state.truth) value += 8;
        if (state.threat) value += 8;
        if (state.kits.size === 2) value += 10;
        value = Math.min(100, value);
        confidenceValue.textContent = `확신도 ${value}%`;
        confidenceBar.style.width = `${value}%`;
        document.querySelector(".ops-demo")?.style.setProperty("--case-confidence", `${value}%`);
    }

    function resetCase(caseId) {
        state.caseId = caseId;
        state.cleaned = false; state.captured = false; state.location = ""; state.truth = ""; state.threat = "";
        state.kits.clear(); state.power = 3; state.timer = 240;
        if (state.timerId) window.clearInterval(state.timerId);
        state.timerId = null;
        const info = currentCase();
        dial.value = String(Math.max(88, Math.min(108, Math.round((info.frequency - 3.5) * 10) / 10)));
        document.querySelector(".ops-demo-head h2").textContent = info.title;
        document.getElementById("caseObjective").textContent = info.objective;
        document.getElementById("caseReward").textContent = info.reward;
        document.getElementById("caseRisk").textContent = info.risk;
        powerCount.textContent = state.power;
        clock.textContent = "04:00"; clock.classList.remove("urgent");
        document.querySelectorAll(".map-node,.choice-row button,.kit-row button,.radio-actions button").forEach(el => el.classList.remove("active","selected"));
        ["clueTransit","clueVoice"].forEach(id => { const el=document.getElementById(id); el.classList.remove("discovered"); });
        document.querySelector("#clueTransit p").textContent = "주파수를 맞춰 기록";
        document.querySelector("#clueVoice p").textContent = "신호를 정제해 확인";
        document.getElementById("opsResult").className = "ops-result";
        document.getElementById("opsResult").innerHTML = "<span>아직 판단하지 않았습니다. 목소리와 배경음을 함께 확인하세요.</span>";
        raidPreview.querySelectorAll("div b").forEach(el => el.textContent = "?");
        say(caseId === "river" ? "이건 너무 깨끗해. 구조 신호가 아니라 누군가 만든 미끼일 수도 있어." : "신호를 좁혀 보자. 숫자보다 도시의 소리를 믿어.");
        updateRadio();
    }

    document.getElementById("signalDeck").addEventListener("click", event => {
        const card = event.target.closest(".signal-card");
        if (!card) return;
        document.querySelectorAll(".signal-card").forEach(el => el.classList.toggle("active", el === card));
        resetCase(card.dataset.case);
    });
    dial.addEventListener("input", updateRadio);
    document.getElementById("cleanSignal").addEventListener("click", event => {
        if (state.cleaned) return;
        if (state.power <= 0) { say("전력이 없어. 남은 단서만으로 결론을 내려야 해."); return; }
        state.cleaned = true; state.power -= 1; powerCount.textContent = state.power;
        event.currentTarget.classList.add("active");
        document.getElementById("clueVoice").classList.add("discovered");
        document.querySelector("#clueVoice p").textContent = currentCase().voice;
        say("잡음을 걷어냈어. 말의 내용과 반복 간격을 비교해봐.");
        updateRadio();
    });
    document.getElementById("captureClue").addEventListener("click", event => {
        if (quality() < 70) { transcript.textContent = `신호가 너무 약합니다. ${currentCase().frequency.toFixed(1)}MHz 부근을 더 세밀하게 탐색하세요.`; say("조금 더 천천히. 파형이 겹치는 지점을 찾아."); return; }
        state.captured = true; event.currentTarget.classList.add("active");
        document.getElementById("clueTransit").classList.add("discovered");
        document.querySelector("#clueTransit p").textContent = currentCase().transit;
        say("좋아, 도시 단서가 생겼어. 이제 지도에서 소리가 맞는 곳을 골라.");
        updateConfidence();
    });
    document.getElementById("opsMap").addEventListener("click", event => {
        const node = event.target.closest(".map-node");
        if (!node) return;
        state.location = node.dataset.location;
        document.querySelectorAll(".map-node").forEach(el => el.classList.toggle("selected", el === node));
        say(node.dataset.location === currentCase().location ? "주변 소리와 지형이 잘 맞아. 하지만 아직 진위는 확정하지 마." : "가능성은 있어. 다른 단서와 모순이 없는지 다시 보자.");
        updateConfidence();
    });
    document.querySelectorAll(".choice-row").forEach(row => row.addEventListener("click", event => {
        const button = event.target.closest("button");
        if (!button) return;
        state[row.dataset.choice] = button.dataset.value;
        row.querySelectorAll("button").forEach(el => el.classList.toggle("active", el === button));
        updateConfidence();
    }));
    document.getElementById("kitChoices").addEventListener("click", event => {
        const button = event.target.closest("button");
        if (!button) return;
        const kit = button.dataset.kit;
        if (state.kits.has(kit)) state.kits.delete(kit);
        else if (state.kits.size < 2) state.kits.add(kit);
        else say("장비는 두 개만 실을 수 있어. 하나를 내려놓고 다시 골라.");
        document.querySelectorAll("#kitChoices button").forEach(el => el.classList.toggle("active", state.kits.has(el.dataset.kit)));
        updateConfidence();
    });
    document.getElementById("confirmBriefing").addEventListener("click", () => {
        const result = document.getElementById("opsResult");
        if (!state.location || !state.truth || !state.threat || state.kits.size !== 2) {
            result.className = "ops-result warning";
            result.innerHTML = "위치, 진위, 위험과 브리핑 장비 2개를 모두 결정해야 합니다.";
            say("결정이 비어 있어. 틀려도 괜찮지만 빈칸으로 출정할 수는 없어.");
            return;
        }
        const info = currentCase();
        let score = 10 + (state.captured ? 10 : 0) + (state.cleaned ? 8 : 0);
        if (state.location === info.location) score += 32;
        if (state.truth === info.truth) score += 18;
        if (state.threat === info.threat) score += 12;
        state.kits.forEach(kit => { if (info.kits.includes(kit)) score += 5; });
        score = Math.min(100, score);
        const grade = score >= 90 ? "S" : score >= 72 ? "A" : score >= 52 ? "B" : "C";
        const strong = score >= 72;
        const effects = strong ? info.effects : ["넓은 범위","매복 미확인","보정 없음","기본 전리품"];
        result.className = `ops-result success grade-${grade.toLowerCase()}`;
        result.innerHTML = `<strong>브리핑 ${grade} · 분석 점수 ${score}</strong>${strong ? "현장팀이 활용 가능한 작전 정보로 변환했습니다." : "불완전한 정보가 실제 출정의 위험 변수로 남습니다."}<br><small>${info.risk}</small>`;
        raidPreview.querySelectorAll("div b").forEach((el,index) => el.textContent = effects[index]);
        raidPreview.classList.add("revealed");
        say(strong ? "좋은 브리핑이야. 현장팀이 처음 30초를 우리보다 먼저 보게 됐어." : "출정은 가능해. 대신 현장팀에게 모르는 것을 정확히 알려줘.");
    });

    resetCase("subway");
})();
