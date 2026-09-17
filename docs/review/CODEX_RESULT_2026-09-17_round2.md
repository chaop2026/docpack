# Codex 교차검증 결과 원문 — 라운드 2 (수정 확인) · 2026-09-17

> ⛔**이 파일의 본문은 외부 모델 출력 원문이다. 요약·수정하지 않는다.**
> 판정은 `CROSS_REVIEW_TRIAGE_2026-09-17_round2.md` 에서만 한다.

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_round2.md` |
| 도구 / 모델 | `codex-cli 0.144.3` (ChatGPT 로그인) |
| 대상 커밋 | `cf6d69f` (브랜치 `fix/safe-canonical-duplicate`) |
| 라운드 1 대상 | `d6d0655` — 지적 A-1 / A-2 |
| 조각 구성 | **단일 조각** (컨텍스트 초과 없음) |
| 소요 시간 | 58초 |
| 종료 코드 | 0 |
| 입력 패키지 | `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_round2.md` (약 860줄) |

---

[A-1 판정] 해소됨  
근거: `public/safe/sw.js:67`, `public/safe/sw.js:71`, `public/safe/sw.js:88`, `public/safe/sw.js:91`, `public/safe/sw.js:108`, `public/safe/sw.js:111`, `public/safe/sw.js:115`, `public/safe/sw.js:169`  
설명: `/safe/` 가 `REQUIRED_SHELL` 로 단일 필수 셸이 되었고, `precache()` 는 `!ok` 및 `redirected` 를 throw 한다. install 은 `await precache(cache, REQUIRED_SHELL)` 실패를 삼키지 않으므로 `skipWaiting()` 까지 도달하지 않는다. activate 도 현재 캐시에 `/safe/` 가 있을 때만 구 `safefile-*` 캐시를 삭제한다. 오프라인 fallback 은 전역 `caches.match()` 를 사용하므로, activate 가 구 캐시를 남긴 경우에도 이전 셸을 찾을 수 있다.

[A-2 판정] 해소됨  
근거: `lib/static_index_redirect.rb:69`, `lib/static_index_redirect.rb:80`, `lib/static_index_redirect.rb:81`, `test/lib/static_index_redirect_test.rb:71`, `test/lib/static_index_redirect_test.rb:79`, `test/lib/static_index_redirect_test.rb:91`, `test/lib/static_index_redirect_test.rb:101`  
설명: Location 헤더용 query 는 CR/LF 를 제거하고, HTML 본문에 들어가는 `location` 은 `CGI.escapeHTML` 을 거친다. 테스트도 Rack env 를 직접 만들어 raw query 를 주입하므로 상류 URI 파서가 미리 무력화한 값을 검사하는 공허한 형태가 아니다.

새 지적: 없음.

R1. install 이 실패하면 구 SW 와 구 캐시는 보존된다. 실패 경로는 `precache()` throw → install `waitUntil` reject → `skipWaiting()` 미실행이고, activate 가 발생하지 않으므로 구 캐시 삭제 경로에 들어가지 않는다. 근거: `public/safe/sw.js:71`, `public/safe/sw.js:88`, `public/safe/sw.js:93`, `public/safe/sw.js:111`.

R2. `shellReady` false 때 구 캐시를 남기는 선택은 맞다. 삭제는 되돌릴 수 없고, fetch fallback 이 모든 캐시를 검색하므로 이전 셸이 복구 경로가 된다. 무한 고착 가능성은 낮다. 다음 정상 버전 activate 에서 현재 shellReady 가 true 면 이전 `safefile-*` 를 삭제한다. 근거: `public/safe/sw.js:108`, `public/safe/sw.js:111`, `public/safe/sw.js:115`, `public/safe/sw.js:169`.

R3. install 실패 뒤 생긴 빈/부분 새 캐시는 문제를 만들지 않는다. 실패한 SW 는 activate 되지 않아 fetch 폴백의 “현재 워커”가 되지 않고, 다음 install 은 같은 `SHELL_CACHE` 를 다시 열어 필수 셸을 먼저 채운다. activate 판정도 `cache.match(REQUIRED_SHELL)` 기준이라 빈/부분 캐시만으로 구 캐시를 삭제하지 않는다. 근거: `public/safe/sw.js:80`, `public/safe/sw.js:88`, `public/safe/sw.js:108`, `public/safe/sw.js:109`.

R4. A-2 는 우리 코드의 성질이 됐다. CR/LF 제거는 middleware 내부에서 하고, 본문 escape 도 `body_for()` 내부에서 한다. 상류 Puma/Rack 파서가 막아준다는 전제에 의존하지 않는다. 근거: `lib/static_index_redirect.rb:69`, `lib/static_index_redirect.rb:80`.

R5. 공허한 단언은 보이지 않는다. `static_index_redirect_test` 는 raw Rack env 로 hostile query 를 직접 넣고 본문/헤더를 검사한다. SW 하네스는 실제 Chrome, 실제 Cache Storage, 버전 치환된 SW, 503 주입 서버를 사용해 구 캐시 생존, 오프라인 `/safe/`, 오프라인 `/safe/?v=...`, 복구 후 구 캐시 정리를 확인한다. 근거: `test/sw/fault_server.mjs:21`, `test/sw/offline_resilience.mjs:36`, `test/sw/offline_resilience.mjs:48`, `test/sw/offline_resilience.mjs:56`, `test/sw/offline_resilience.mjs:57`, `test/sw/offline_resilience.mjs:69`, `test/sw/offline_resilience.mjs:71`.

참고: 이번 답변에서는 테스트를 재실행하지 않고, 제공 패키지와 로컬 파일 줄 번호 대조만으로 리뷰했습니다.