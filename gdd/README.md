# Project Atlas

`index.html`은 게임 디자인 문서와 프로젝트 에셋을 한 화면에서 확인하는 로컬 GDD 허브입니다.

새 에셋, 씬, 스크립트 또는 테스트가 추가된 뒤 다음 명령을 실행하면 카탈로그 수치와 이미지 목록이 갱신됩니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\update_gdd_catalog.ps1
```

생성된 `project-data.js`는 별도 서버 없이 `index.html`을 직접 열어도 동작하도록 설계되어 있습니다.
