(() => {
    const data = window.PROJECT_DATA || { assets: [], stats: {}, generated_at: "-" };
    const views = [...document.querySelectorAll(".view")];
    const navItems = [...document.querySelectorAll(".nav-item")];
    const pageNames = {overview:"프로젝트 개요",design:"게임 디자인",systems:"시스템 지도",assets:"에셋 라이브러리",operations:"심야 구조 관제실",roadmap:"개발 현황"};
    const number = value => new Intl.NumberFormat("ko-KR").format(value || 0);
    const rel = path => "../" + path.replaceAll("\\", "/");

    function showView(id) {
        views.forEach(view => view.classList.toggle("active", view.id === id));
        navItems.forEach(item => item.classList.toggle("active", item.dataset.view === id));
        document.getElementById("pageName").textContent = pageNames[id];
        document.querySelector(".rail").classList.remove("open");
        window.scrollTo({top: 0, behavior: "smooth"});
        history.replaceState(null, "", "#" + id);
    }
    navItems.forEach(item => item.addEventListener("click", () => showView(item.dataset.view)));
    document.querySelectorAll(".jump").forEach(button => button.addEventListener("click", () => showView(button.dataset.target)));
    document.getElementById("mobileMenu").addEventListener("click", () => document.querySelector(".rail").classList.toggle("open"));

    const initialView = location.hash.slice(1);
    if (pageNames[initialView]) showView(initialView);

    const s = data.stats;
    document.getElementById("buildStamp").textContent = `SCAN · ${data.generated_at || "-"}`;
    document.getElementById("overviewStats").innerHTML = [
        [number(s.images), "이미지 에셋"], [number(s.runtime_images), "게임 적용 후보"], [number(s.scripts), "게임 스크립트"],
        [number(s.scenes), "Godot 씬"], [number(s.tests), "검증 시나리오"]
    ].map(x => `<div class="stat-card"><strong>${x[0]}</strong><span>${x[1]}</span></div>`).join("");
    document.getElementById("snapshotList").innerHTML = [
        ["Godot 버전", data.project?.godot_version || "4.5.1"], ["주요 플랫폼", "Windows · Web · Mobile"],
        ["현재 중심 지역", "종로 생존구역"], ["목표 세션", "20–30분"], ["레이드 가방", "15 슬롯"],
        ["최초 쉘터 규모", "구조 고양이 5마리"]
    ].map(x => `<div class="snapshot-row"><span>${x[0]}</span><b>${x[1]}</b></div>`).join("");

    const heroCandidates = ["assets/backgrounds", "assets/buildings", "assets/opening"];
    const hero = data.assets.find(a => heroCandidates.some(p => a.path.startsWith(p)) && a.width >= 900) || data.assets.find(a => a.category === "buildings");
    if (hero) document.getElementById("heroVisual").style.backgroundImage = `url('${rel(hero.path)}')`;

    const designCards = [
        ["01","플레이어 판타지","전술 장비를 갖춘 고양이가 폐허가 된 서울을 탐색하고 생존자들을 모아 구조대를 성장시킨다.",["아이소메트릭 2.5D","익스트랙션 생존","고양이 구조대"]],
        ["02","세션 구조","준비, 탐색, 가방 선택, 위험한 탈출, 쉘터 성장이 하나의 20~30분 흐름으로 이어진다.",["다중 탈출로","필드·빌딩 연속성","사망과 시체 회수"]],
        ["03","전투와 잠입","총기 전투와 시야·소리 기반 은신이 공존한다. 적과 환경을 읽고 교전 여부를 결정한다.",["조준·대시·근접","인지와 경계 단계","원거리 적과 보스"]],
        ["04","전리품 경제","지역 티어와 컨테이너 유형이 전리품을 결정한다. 무기보다 탄약과 부품의 지속 가치가 중요하다.",["15칸 가방","가치/슬롯 지표","청사진·키카드 게이트"]],
        ["05","서울 절차 생성","도로와 도시 구획을 기준으로 상업·주거·시장·공업 지역의 규칙과 에셋이 달라진다.",["도시개발 구획","건물 내부 던전","랜드마크와 원경"]],
        ["06","쉘터와 주민","전리품을 수리·분해·납품하고 구조한 고양이를 배치해 다음 레이드를 준비한다.",["모듈형 설비","제작·훈련·휴식","구조대 공방 비전"]]
    ];
    document.getElementById("designGrid").innerHTML = designCards.map(c => `<article class="design-card" data-num="${c[0]}"><span class="index">PILLAR ${c[0]}</span><h2>${c[1]}</h2><p>${c[2]}</p><ul>${c[3].map(x=>`<li>${x}</li>`).join("")}</ul></article>`).join("");

    const systems = [
        {cat:"코어",name:"플레이어 액션",status:"구현",p:88,desc:"이동, 대시, 조준, 사격, 재장전, 근접 공격과 모바일 조작.",owner:"main / weapon_system"},
        {cat:"코어",name:"장면 상태 보존",status:"개선 중",p:70,desc:"필드·빌딩·쉘터 전환 시 장비, 탄약, 부상과 레이드 상태를 유지.",owner:"game_state / transition_guard"},
        {cat:"전투",name:"적 인지와 전투",status:"구현",p:82,desc:"시야·소리 기반 경계, 원거리 공격, 투척형 적과 로켓 보스.",owner:"enemy / perception"},
        {cat:"전투",name:"스텔스",status:"구현",p:78,desc:"조명, 소리, 경계 단계, 은신 처치와 냄새 흔적 추적.",owner:"perception / scent"},
        {cat:"필드",name:"절차적 서울",status:"확장 중",p:76,desc:"도시 구획, 도로, 건물, 차량, 하천, 랜드마크와 지역 테마 생성.",owner:"procedural_map"},
        {cat:"필드",name:"건물 내부",status:"개선 중",p:65,desc:"독립 층 시드, 사무실 방과 복도, 적·전리품, 엘리베이터 이동.",owner:"building_interior"},
        {cat:"전리품",name:"루팅 경제",status:"구현",p:84,desc:"지역 티어 × 컨테이너 필터, 가치 상한, 무기·탄약·재료 드롭.",owner:"loot_economy / raid_item"},
        {cat:"전리품",name:"레이드 가방",status:"구현",p:86,desc:"15칸 제한, 아이템 크기, 교체 선택과 회수품 관리.",owner:"inventory / loot_swap"},
        {cat:"탈출",name:"다중 탈출",status:"구현",p:80,desc:"일반·위험·고위험 탈출 조건과 보상 배율, 비상 하수구 동선.",owner:"extraction_policy"},
        {cat:"쉘터",name:"모듈형 쉘터",status:"확장 중",p:72,desc:"침대, 제작대, 보관함, 훈련, 상인과 1단계 거주 공간.",owner:"shelter_interior"},
        {cat:"쉘터",name:"주민과 성장",status:"기반",p:52,desc:"구조한 고양이, 계약, 능력 성장과 장기 구조대 운영 기반.",owner:"game_state / resident"},
        {cat:"UX",name:"전술 HUD",status:"개선 중",p:68,desc:"체력·피로·무기·조준·상호작용·가방·전술 지도 정보.",owner:"hud / tactical_map"},
        {cat:"UX",name:"모바일 보조",status:"구현",p:74,desc:"가상 스틱, 발사·대시·근접 버튼, 방향 원뿔 기반 조준 보정.",owner:"main / safe_area"},
        {cat:"콘텐츠",name:"동적 사건",status:"기반",p:62,desc:"핫스폿, 봉인 화물, 발전기, 경보 증원과 추락 호송대 사건.",owner:"main / field_mission"},
        {cat:"접근성",name:"화면 접근성",status:"기반",p:45,desc:"안전 영역, 조준선과 UI 표시를 위한 설정 카탈로그.",owner:"accessibility_settings"}
    ];
    const tones = {"구현":"#7bb6a5","개선 중":"#d6a956","확장 중":"#6e91a3","기반":"#9a7aa2"};
    const cats = ["전체",...new Set(systems.map(x=>x.cat))];
    document.getElementById("systemFilters").innerHTML = cats.map((c,i)=>`<button class="chip ${i===0?'active':''}" data-cat="${c}">${c}</button>`).join("");
    function renderSystems(cat="전체", query="") {
        const q=query.toLowerCase();
        document.getElementById("systemGrid").innerHTML = systems.filter(x=>(cat==="전체"||x.cat===cat)&&(!q||`${x.name} ${x.desc} ${x.owner}`.toLowerCase().includes(q))).map(x=>`<article class="system-card" style="--tone:${tones[x.status]};--progress:${x.p}%"><header><h3>${x.name}</h3><span class="badge">${x.status}</span></header><p>${x.desc}</p><footer><span>${x.cat} · ${x.owner}</span><span class="progress"><i></i></span></footer></article>`).join("");
    }
    renderSystems();
    document.getElementById("systemFilters").addEventListener("click", e => {if(!e.target.matches("button"))return;document.querySelectorAll("#systemFilters button").forEach(b=>b.classList.remove("active"));e.target.classList.add("active");renderSystems(e.target.dataset.cat)});

    const catalogGroups = {
        all:{label:"전체",icon:"◫"}, characters:{label:"캐릭터",icon:"♟"}, buildings:{label:"건물",icon:"▥"},
        items:{label:"아이템·장비",icon:"◇"}, ui:{label:"UI",icon:"⌗"}, vehicles:{label:"차량",icon:"▰"},
        interiors:{label:"실내·쉘터",icon:"⌂"}, world:{label:"환경·맵",icon:"▱"}, props:{label:"프랍·상호작용",icon:"⚑"},
        cinematics:{label:"연출",icon:"◉"}, production:{label:"제작 소스",icon:"◎"}, other:{label:"기타",icon:"·"}
    };
    const characters = {
        nabi:{name:"나비 (Nabi)",role:"주인공 · 종로 정찰묘",code:"CHAR_NABI",desc:"검은 털과 흰 얼굴 무늬, 붉은 스카프와 전술 배낭을 착용한 플레이어 캐릭터. 재앙 이전 누군가의 집고양이였고, 그때 불리던 이름을 아직 쓴다."},
        seorin:{name:"서린",role:"동료 · 생존 전투묘",code:"CHAR_SEORIN",desc:"검은 코트와 전술 장비를 갖춘 여성 동료 고양이."},
        moka:{name:"모카",role:"구조 주민 · 겁먹은 상태",code:"CHAR_MOKA",desc:"베이지색 장모의 어린 구조 주민. 구조와 회복 장면에 사용."},
        dodam:{name:"도담",role:"쉘터 주민 · 작업묘",code:"CHAR_DODAM",desc:"베이지색 장모 주민의 작업·이동 스프라이트 세트."},
        jango:{name:"장고",role:"쉘터 주민 · 물물교환 상인",code:"CHAR_JANGO",desc:"붉은 옷을 입은 쉘터 상인 캐릭터."},
        bonggu:{name:"봉구",role:"적 · 폐허 약탈자",code:"ENEMY_BONGGU",desc:"누더기 전술복과 중장비를 갖춘 육중한 약탈자."},
        lumi:{name:"루미",role:"NPC · 유물 감정상",code:"CHAR_LUMI",desc:"회중시계와 붉은 조끼를 착용한 삼색 고양이. 감정·거래 역할 후보."},
        gangcheol:{name:"강철",role:"적 · 근접 중장병",code:"ENEMY_GANGCHEOL",desc:"강한 체격과 붕대를 갖춘 스핑크스 근접 전투원."},
        tani:{name:"탄이",role:"NPC · 시설 정비공",code:"CHAR_TANI",desc:"안전모와 공구 허리띠를 착용한 장모 정비공."},
        pohwa:{name:"포화",role:"보스 · 로켓 중화기병",code:"BOSS_POHWA",desc:"대형 로켓 발사기를 사용하는 중장 보스 고양이."},
        pin:{name:"핀",role:"적 · 수류탄 투척병",code:"ENEMY_PIN",desc:"경량 전술복과 투척물을 갖춘 기동형 원거리 적."},
        danpung:{name:"단풍",role:"NPC · 붉은 작업복 주민",code:"CHAR_DANPUNG",desc:"주황색 털과 붉은 작업복을 입은 쉘터 주민 후보."},
        hana:{name:"하나",role:"초기 생존자 시트",code:"CHAR_HANA_LEGACY",desc:"초기 제작된 인간형 생존자 방향·사격 애니메이션 자료."},
        raider_marksman:{name:"까마귀",role:"적 · 권총 사수",code:"ENEMY_RAIDER_MARKSMAN",desc:"권총을 사용하는 초기 약탈자 콘셉트와 방향 스프라이트."},
        raider_bruiser:{name:"멧돌",role:"적 · 근접 돌격수",code:"ENEMY_RAIDER_BRUISER",desc:"근접전을 시도하는 초기 약탈자 콘셉트와 방향 스프라이트."},
        unassigned:{name:"미분류",role:"이름 지정 대기",code:"CHAR_UNASSIGNED",desc:"아직 정식 이름이나 역할이 연결되지 않은 캐릭터 제작 이미지."}
    };
    let activeGroup="all", activeCharacter="all";
    const groupCount=id=>data.assets.filter(a=>(a.catalog_group||a.category)===id).length;
    document.getElementById("categoryChips").innerHTML=Object.entries(catalogGroups).filter(([id])=>id==="all"||groupCount(id)>0).map(([id,g])=>`<button class="category-chip ${id==='all'?'active':''}" data-group="${id}"><i>${g.icon}</i><span>${g.label}</span><small>${id==='all'?data.assets.length:groupCount(id)}</small></button>`).join("");
    const characterIds=Object.keys(characters).filter(id=>data.assets.some(a=>a.character_id===id));
    document.getElementById("characterTabs").innerHTML=`<button class="character-tab active" data-character="all"><b>전체 캐릭터</b><small>${groupCount('characters')} ASSETS</small></button>`+characterIds.map(id=>`<button class="character-tab" data-character="${id}"><b>${characters[id].name}</b><small>${data.assets.filter(a=>a.character_id===id).length} · ${characters[id].role.split(' · ')[0]}</small></button>`).join("");
    document.getElementById("assetTotal").textContent = number(data.assets.length);
    let shown = 48, mode = "grid", filteredAssets = [];
    function assetStatus(a){if(a.path.includes("/generated/"))return "generated";if(/reference|source|request|raw/i.test(a.path))return "reference";return "runtime"}
    function assetGroup(a){return a.catalog_group||a.category}
    function characterInfo(a){return characters[a.character_id]||characters.unassigned}
    function representativeFor(id){return data.assets.filter(a=>a.character_id===id).sort((a,b)=>{const score=x=>(/base-reference|base-source|down_idle_0|down_idle-frame-0|concept/i.test(x.name)?10:0)+(assetStatus(x)==="runtime"?4:0)-(x.path.includes('/raw/')?5:0);return score(b)-score(a)})[0]}
    function renderCharacterProfile(){
        const profile=document.getElementById("characterProfile");
        if(activeCharacter==="all"){profile.classList.remove("visible");profile.innerHTML="";return}
        const info=characters[activeCharacter],rep=representativeFor(activeCharacter),count=data.assets.filter(a=>a.character_id===activeCharacter).length;
        profile.innerHTML=`<div class="character-avatar">${rep?`<img src="${rel(rep.path)}" alt="${info.name}">`:''}</div><div><h3>${info.name} <small>· ${info.role}</small></h3><p>${info.desc}</p><code>${info.code}</code></div><span>${number(count)} SPRITES</span>`;
        profile.classList.add("visible");
    }
    function renderAssets(reset=true){
        if(reset)shown=48;
        const q=document.getElementById("assetSearch").value.trim().toLowerCase(), status=document.getElementById("statusFilter").value, sort=document.getElementById("sortAssets").value;
        filteredAssets=data.assets.filter(a=>(activeGroup==="all"||assetGroup(a)===activeGroup)&&(activeCharacter==="all"||a.character_id===activeCharacter)&&(status==="all"||assetStatus(a)===status)&&(!q||`${a.name} ${a.path} ${characterInfo(a).name} ${characterInfo(a).role}`.toLowerCase().includes(q)));
        filteredAssets.sort((a,b)=>sort==="name"?a.name.localeCompare(b.name):sort==="size"?b.bytes-a.bytes:sort==="newest"?b.modified.localeCompare(a.modified):assetGroup(a).localeCompare(assetGroup(b))||a.name.localeCompare(b.name));
        const page=filteredAssets.slice(0,shown);
        document.getElementById("assetGrid").className=`asset-grid ${mode==='list'?'list':''}`;
        document.getElementById("assetGrid").innerHTML=page.map(a=>`<article class="asset-card" tabindex="0" data-index="${data.assets.indexOf(a)}"><div class="asset-thumb"><img src="${rel(a.path)}" alt="${a.name}" loading="lazy"></div><div class="asset-copy"><span>${catalogGroups[assetGroup(a)]?.label||a.category}${assetGroup(a)==='characters'?' · '+characterInfo(a).name:''}</span><h3 title="${a.name}">${a.name}</h3><p>${a.width||'?'}×${a.height||'?'} · ${a.kb} KB · ${assetStatus(a)}</p></div></article>`).join("");
        document.getElementById("assetResultCount").textContent=`${number(filteredAssets.length)}개 중 ${number(page.length)}개 표시`;
        document.getElementById("loadMore").style.display=shown<filteredAssets.length?"block":"none";
        document.getElementById("emptyAssets").style.display=filteredAssets.length?"none":"block";
    }
    ["assetSearch","statusFilter","sortAssets"].forEach(id=>document.getElementById(id).addEventListener(id==="assetSearch"?"input":"change",()=>renderAssets()));
    document.getElementById("categoryChips").addEventListener("click",e=>{const button=e.target.closest(".category-chip");if(!button)return;activeGroup=button.dataset.group;activeCharacter="all";document.querySelectorAll(".category-chip").forEach(b=>b.classList.toggle("active",b===button));document.getElementById("characterBrowser").classList.toggle("visible",activeGroup==="characters");document.querySelectorAll(".character-tab").forEach((b,i)=>b.classList.toggle("active",i===0));renderCharacterProfile();renderAssets()});
    document.getElementById("characterTabs").addEventListener("click",e=>{const button=e.target.closest(".character-tab");if(!button)return;activeCharacter=button.dataset.character;document.querySelectorAll(".character-tab").forEach(b=>b.classList.toggle("active",b===button));renderCharacterProfile();renderAssets()});
    document.getElementById("loadMore").addEventListener("click",()=>{shown+=48;renderAssets(false)});
    document.querySelector(".view-toggle").addEventListener("click",e=>{if(!e.target.matches("button"))return;mode=e.target.dataset.mode;document.querySelectorAll(".view-toggle button").forEach(b=>b.classList.toggle("active",b===e.target));renderAssets(false)});
    renderAssets();

    const dialog=document.getElementById("assetDialog"); let selectedAsset=null;
    function openAsset(index){selectedAsset=data.assets[index];if(!selectedAsset)return;document.getElementById("dialogImage").src=rel(selectedAsset.path);document.getElementById("dialogImage").alt=selectedAsset.name;document.getElementById("dialogCategory").textContent=`${catalogGroups[assetGroup(selectedAsset)]?.label||selectedAsset.category}${assetGroup(selectedAsset)==='characters'?' · '+characterInfo(selectedAsset).name:''} · ${assetStatus(selectedAsset)}`;document.getElementById("dialogTitle").textContent=selectedAsset.name;document.getElementById("dialogPath").textContent=selectedAsset.path;document.getElementById("dialogMeta").innerHTML=`${assetGroup(selectedAsset)==='characters'?`<dt>캐릭터</dt><dd>${characterInfo(selectedAsset).name} · ${characterInfo(selectedAsset).code}</dd>`:''}<dt>크기</dt><dd>${selectedAsset.width||'?'} × ${selectedAsset.height||'?'} px</dd><dt>파일 용량</dt><dd>${selectedAsset.kb} KB</dd><dt>수정일</dt><dd>${selectedAsset.modified}</dd><dt>형식</dt><dd>${selectedAsset.ext.toUpperCase()}</dd>`;dialog.showModal()}
    document.getElementById("assetGrid").addEventListener("click",e=>{const card=e.target.closest(".asset-card");if(card)openAsset(Number(card.dataset.index))});
    document.getElementById("assetGrid").addEventListener("keydown",e=>{if(e.key!=="Enter")return;const card=e.target.closest(".asset-card");if(card)openAsset(Number(card.dataset.index))});
    document.querySelector(".dialog-close").addEventListener("click",()=>dialog.close());
    document.getElementById("copyPath").addEventListener("click",async()=>{if(!selectedAsset)return;await navigator.clipboard.writeText(selectedAsset.path);document.getElementById("copyPath").textContent="복사됨";setTimeout(()=>document.getElementById("copyPath").textContent="경로 복사",1000)});

    document.getElementById("healthGrid").innerHTML=[
        [s.tests,"검증 시나리오","기능별 스모크 테스트"],[s.scripts,"게임 스크립트","현재 코드 모듈"],[s.scenes,"Godot 씬","플레이·모듈 씬"],[s.asset_categories,"에셋 분류","폴더 기준 카탈로그"]
    ].map(x=>`<article class="health-card"><span>${x[1]}</span><strong>${number(x[0])}</strong><p>${x[2]}</p></article>`).join("");
    const roadmap={
        "P0 · 일관성":[["필드/실내 코어 통합","장소가 바뀌어도 조작과 HUD를 동일하게 유지"],["장면 상태 보존","장비·탄약·피로·전리품 전환 검증"],["충돌 규격화","이미지 발밑과 이동·투사체 판정 일치"]],
        "P1 · 수직 슬라이스":[["20~30분 종로 한 판","준비부터 쉘터 복귀까지 반복 플레이"],["위험·보상 재조정","지역 티어와 실제 획득 가치 계측"],["탈출 차별화","세 경로의 조건과 플레이 감각 분리"]],
        "P2 · 장기 성장":[["구조대 공방","감정·수리·분해·납품의 쉘터 코어"],["주민 역할","구조 고양이의 작업 특성과 관계"],["도시 상태 변화","의뢰 결과가 다음 레이드에 반영"]]
    };
    document.getElementById("roadmapBoard").innerHTML=Object.entries(roadmap).map(([title,items],ci)=>`<section class="road-column"><header><h2>${title}</h2><span>${items.length} ITEMS</span></header>${items.map((x,i)=>`<article class="road-item" style="--tone:${["#c96d5e","#d6a956","#7bb6a5"][ci]}"><b>${x[0]}</b><p>${x[1]}</p></article>`).join("")}</section>`).join("");

    const global=document.getElementById("globalSearch");
    global.addEventListener("keydown",e=>{if(e.key==="Enter"&&global.value.trim()){showView("assets");document.getElementById("assetSearch").value=global.value;renderAssets()}});
    document.addEventListener("keydown",e=>{if(e.key==="/"&&document.activeElement.tagName!=="INPUT"){e.preventDefault();global.focus()}if(e.key==="Escape"&&dialog.open)dialog.close()});
    const initial=location.hash.slice(1);if(pageNames[initial])showView(initial);
})();
