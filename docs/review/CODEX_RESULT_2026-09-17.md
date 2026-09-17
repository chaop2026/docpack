# Codex 교차검증 결과 원문 — 2026-09-17

> ⛔**이 파일의 본문은 외부 모델 출력 원문이다. 요약·수정하지 않는다.**
> 판정은 `CROSS_REVIEW_TRIAGE_2026-09-17.md` 에서만 한다.

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-17.md` |
| 도구 / 모델 | `codex-cli 0.144.3` (ChatGPT 로그인) |
| 대상 커밋 | `d6d0655` (브랜치 `fix/safe-canonical-duplicate`) |
| 조각 구성 | **단일 조각** (패키지 전체를 한 번에 stdin 투입, 컨텍스트 초과 없음) |
| 소요 시간 | 69초 |
| 종료 코드 | 0 |
| 입력 패키지 | `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17.md` (약 960줄) |

---

[논리 오류] [확신도 높음] 새 서비스워커 설치가 셸 캐시 실패를 성공처럼 처리한 뒤 기존 오프라인 캐시를 삭제할 수 있음  
근거: `public/safe/sw.js:63`, `public/safe/sw.js:66`, `public/safe/sw.js:68`, `public/safe/sw.js:72`, `public/safe/sw.js:77`, `public/safe/sw.js:78`  
설명: 설치 중 `/safe/` 프리캐시가 실패해도 `.catch(() => null)` 때문에 install 은 성공하고 `skipWaiting()` 한다. activate 에서는 이전 `safefile-*` 캐시를 모두 삭제한다. 즉 기존 방문자가 업데이트는 받았지만 `/safe/` 셸 fetch 가 일시 실패한 경우, 정상 작동하던 구버전 오프라인 셸을 삭제하고 새 셸도 없는 상태가 될 수 있다. 이 패키지의 반복 실패 유형으로 보면 “조용한 실패”와 “캐시 고착/전환” 계열이다. 최소한 `/safe/` 자체는 설치 실패를 install 실패로 올려서 기존 SW와 기존 캐시가 유지되게 해야 한다.

[보안] [확신도 낮음] 301 HTML 본문이 쿼리 문자열 포함 Location 을 이스케이프 없이 반사함  
근거: `lib/static_index_redirect.rb:40`, `lib/static_index_redirect.rb:42`, `lib/static_index_redirect.rb:54`  
설명: `QUERY_STRING` 을 붙인 `location` 을 HTML 속성값과 텍스트 노드에 그대로 넣는다. 일반 브라우저 링크에서는 위험 문자가 percent-encode 될 가능성이 높지만, 서버/Rack 앞단이 raw `<`, `"`, `&` 등을 허용하는 요청을 넘기면 리다이렉트 본문에서 HTML/속성 주입이 가능하다. 301 본문은 보통 사용자가 보지 않지만 `text/html` 로 내려가므로 방어적으로 escape 하는 편이 맞다.

**Q1~Q5 답변**

Q1. `StaticIndexRedirect` 위치 자체가 Propshaft 에셋, `/api/`, Active Storage, manifest/SW, `/up` 을 깨뜨리는 증거는 패키지 안에서는 보이지 않는다. 매칭이 `PATH_INFO == "/safe"` 또는 `"/safe/index.html"` 및 `/privacy` 쌍으로만 제한되어 있어서 다른 경로는 통과한다. 단, `public_file_server.enabled` 가 꺼진 배포 형태에서는 이 미들웨어도 빠지므로, 그 경우 앞단에서 같은 정규화가 필요하다.

Q2. 301 에 `Cache-Control: no-cache` 를 붙이는 판단은 SEO상 큰 문제로 보이지 않는다. 상태코드는 여전히 301 이고, `no-cache` 는 브라우저가 저장 전 재검증하라는 의미라서 잘못 고정된 301을 피하려는 목적과 맞다.

Q3. 전환은 “대부분 안전하지만 완전히 안전하지는 않다.” 새 SW가 `/safe/` 를 성공적으로 프리캐시하면 `/safe/index.html` 오프라인 요청도 최종적으로 `/safe/` fallback 으로 살아난다. 문제는 위 지적처럼 `/safe/` 프리캐시 실패를 성공 처리한 뒤 기존 캐시를 삭제할 수 있다는 점이다.

Q4. 실제 언어별 URL 이 없으므로 `ko/en/ja/es` hreflang 을 같은 URL로 여러 개 거는 것보다 `x-default` 자기참조 하나가 더 정직한 신호다. 다만 원시 HTML title/description 은 한국어이고 렌더 본문은 Googlebot 환경에서 영어가 될 수 있어, “단일 URL 다국어” 구조의 검색 신호는 본질적으로 약하다. 한국어 노출을 우선하려는 판단이라면 현재 보류는 이해 가능하다.

Q5. 완전히 공허한 단언은 보이지 않는다. 다만 서비스워커 전환 위험은 현재 통합 테스트 범위 밖이다. 특히 `/safe/` 프리캐시 실패 시 install 이 성공하고 activate 가 기존 캐시를 삭제하는 경로는 테스트가 보장하지 않는다.