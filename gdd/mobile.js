(async () => {
    const loader = document.getElementById("mobileLoader");
    try {
        const response = await fetch("index.html", { cache: "no-store" });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const source = new DOMParser().parseFromString(await response.text(), "text/html");
        source.querySelectorAll("script").forEach(script => script.remove());
        document.body.innerHTML = source.body.innerHTML;
        document.body.className = "mobile-atlas";

        const loadScript = src => new Promise((resolve, reject) => {
            const script = document.createElement("script");
            script.src = src;
            script.onload = resolve;
            script.onerror = reject;
            document.body.appendChild(script);
        });

        await loadScript("project-data.js?v=atlas-3");
        await loadScript("app.js?v=atlas-3");
        await loadScript("operations.js?v=atlas-3");

        const brand = document.querySelector(".brand small");
        if (brand) brand.textContent = "GREY DAWN · MOBILE";

        const bottomNav = document.createElement("nav");
        bottomNav.className = "mobile-bottom-nav";
        bottomNav.setAttribute("aria-label", "모바일 주요 메뉴");
        bottomNav.innerHTML = [
            ["overview", "개요"], ["design", "디자인"], ["systems", "시스템"],
            ["assets", "에셋"], ["roadmap", "현황"]
        ].map(([view, label], index) => `<button type="button" data-mobile-view="${view}" class="${index === 0 ? "active" : ""}">${label}</button>`).join("");
        document.body.appendChild(bottomNav);

        const syncBottomNav = () => {
            const activeView = document.querySelector(".view.active")?.id || "overview";
            const normalized = activeView === "operations" ? "design" : activeView;
            bottomNav.querySelectorAll("button").forEach(button => button.classList.toggle("active", button.dataset.mobileView === normalized));
        };
        bottomNav.addEventListener("click", event => {
            const button = event.target.closest("button[data-mobile-view]");
            if (!button) return;
            document.querySelector(`.nav-item[data-view="${button.dataset.mobileView}"]`)?.click();
            syncBottomNav();
        });
        document.querySelectorAll(".nav-item,.jump").forEach(button => button.addEventListener("click", () => setTimeout(syncBottomNav)));
        syncBottomNav();
    } catch (error) {
        document.body.innerHTML = `<main class="mobile-loader"><strong>문서를 불러오지 못했습니다.</strong><small>${error.message}</small><a href="index.html">기본 사이트 열기</a></main>`;
    }
})();
