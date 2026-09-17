# 교차검증 대조(triage) — /safe/ canonical & URL de-duplication

- 대상 커밋: `d6d0655` (브랜치 `fix/safe-canonical-duplicate`, **미배포**)
- 외부 모델 출력 원문: [`CODEX_RESULT_2026-09-17.md`](CODEX_RESULT_2026-09-17.md)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-17.md`](CODEX_REVIEW_PACKAGE_2026-09-17.md)
- 🔴 **이 세션에서는 (a) 를 고치지 않았다.** 아래 (a) 2건은 **다음 수정 런의 입력**이다.

지적 총 2건 + Q1~Q5 답변 5건 = **7건 전부 분류했다.**

---

## (a) 진짜 문제 — 2건

### A-1. 서비스워커: `/safe/` 프리캐시 실패를 성공 처리한 뒤 구버전 캐시를 지운다 — **AMBER**

**Codex 지적**: `[논리 오류][확신도 높음]` install 이 `.catch(() => null)` 로 실패를 삼키고
`skipWaiting()` → activate 가 이전 `safefile-*` 캐시를 전부 삭제한다. 셸 fetch 가 일시 실패하면
멀쩡하던 구버전 오프라인 셸을 잃고 새 셸도 없는 상태가 된다.

**코드로 확인함** — `public/safe/sw.js`:

```js
Promise.all(SHELL_ASSETS.map((u) =>
  fetch(new Request(u, { cache: 'reload' }))
    .then((r) => (r && r.ok) ? cache.put(u, r.clone()) : null)
    .catch(() => null)          // ← 실패를 삼킨다
)).then(() => self.skipWaiting())
```
```js
keys.filter((k) => k.startsWith('safefile-') && k !== SHELL_CACHE && k !== RUNTIME_CACHE)
    .map((k) => caches.delete(k))   // ← 구버전 캐시 무조건 삭제
```

**재현 절차**: 오프라인 셸을 이미 가진 방문자가, 배포 직후 `/safe/` 를 여는 순간 네트워크가
끊기거나 5xx 를 맞는다 → 새 SW install 은 "성공" → activate 가 구버전 셸 캐시 삭제 →
그 시점부터 다음 온라인 방문 전까지 오프라인으로 열리지 않는다.

**이 커밋이 만든 문제인가 — 부분적으로 그렇다.**
근본 결함(실패를 삼키는 install + 무조건 삭제하는 activate)은 **이 커밋 이전부터 있었다.**
다만 수정 전에는 `SHELL_ASSETS` 에 HTML 셸이 `/safe/` 와 `/safe/index.html` **둘**이었고
폴백이 `caches.match('/safe/index.html')` 이라, 하나가 실패해도 다른 하나가 받쳐줬다.
이 커밋이 `/safe/index.html` 을 제거해(301 이 되었으므로 `cache.put()` 이 거부한다)
**이중화가 단일화됐다.** 근본 결함은 그대로 두고 여유분만 줄인 셈이다.

**완화 요인 (그래서 RED 가 아니라 AMBER)**: HTML 내비게이션 핸들러가 성공할 때마다
`c.put(request, copy)` 로 셸을 다시 캐시한다. 즉 **다음 온라인 방문 한 번이면 자가 복구**된다.
영구 손상이 아니라 "다음 접속 전까지 오프라인 불가" 창이다.

**예상 수정 범위** (다음 런): `public/safe/sw.js` 한 파일.
`/safe/` 를 **필수 자산**으로 분리해 실패 시 install 을 실패시킨다(구 SW·구 캐시가 살아남는다).
나머지 아이콘·매니페스트는 지금처럼 개별 실패를 허용한다. 회귀 테스트는 Playwright 에서
`/safe/` 응답만 가로채 실패시킨 뒤 구버전 캐시 생존을 확인하는 형태.

---

### A-2. 301 본문이 쿼리스트링을 이스케이프 없이 반사한다 — **GREEN (현재 스택에서 도달 불가)**

**Codex 지적**: `[보안][확신도 낮음]` `lib/static_index_redirect.rb` 가 `QUERY_STRING` 을
붙인 `location` 을 HTML 속성값과 텍스트 노드에 그대로 넣는다.

**코드 인용** — `lib/static_index_redirect.rb:54`:
```ruby
["<html><body>Moved Permanently: <a href=\"#{location}\">#{location}</a></body></html>"]
```
`location` 에는 검증되지 않은 `env["QUERY_STRING"]` 이 들어 있다. **지적 자체는 사실이다.**

**다만 현재 스택에서는 도달할 수 없다 — 실측함** (로컬 Puma 7.2.0, raw socket):

| 요청 | 결과 |
|---|---|
| `GET /safe?x=<b>` | **400** — `Puma::HttpParserError` (Rack 에 도달조차 안 함) |
| `GET /safe?x="q"` | **400** — 동일 |
| `GET /safe?x=%22%3E%3Cscript%3Ealert(1)%3C/script%3E` | 301, 본문에 `%22%3E%3Cscript%3E…` 로 **percent-encoded 그대로** — HTML 로 해석되지 않음 |
| `GET /safe?a=1%0d%0aX-Injected:%20yes` | 301, `location` 헤더에 `%0d%0a` 그대로 — **헤더 주입 없음** |

즉 raw `<` `>` `"` 는 Puma 파서가 400 으로 거른다. 게다가 브라우저는 `Location` 이 있는 301 의
본문을 **렌더하지 않는다**(리다이렉트를 따라간다).

**그럼에도 (c) 오탐이 아니라 (a) 로 분류하는 이유**: 안전한 이유가 *우리 코드*가 아니라
*상위 파서가 마침 그 바이트를 거부한다*는 데 있다. 프록시·서버 교체 한 번이면 가정이 깨진다.
이 저장소가 반복해 당한 "조용한 실패"와 같은 모양이다 — **암묵적 상류 의존**.

**예상 수정 범위** (다음 런): `lib/static_index_redirect.rb` 3줄.
`CGI.escapeHTML(location)` 을 쓰거나, 더 간단하게 **본문에서 URL 반사를 없애고**
고정 문자열(`"Moved Permanently"`)만 내보낸다. 301 본문은 어차피 아무도 보지 않는다.
후자를 권한다 — 이스케이프를 안 빠뜨렸는지 계속 신경 쓸 이유 자체를 없앤다.

---

## (b) 의견 차이 — 우리가 맞음 — 1건

### B-1. Q4 — "단일 URL 다국어 구조의 검색 신호는 본질적으로 약하다"

Codex 답변: `ko/en/ja/es` 를 같은 URL 로 여러 개 거는 것보다 `x-default` 자기참조 하나가
더 정직한 신호다. 다만 원시 HTML title/description 은 한국어, 렌더 본문은 Googlebot 환경에서
영어일 수 있어 신호가 약하다. **"한국어 노출을 우선하려는 판단이라면 현재 보류는 이해 가능하다."**

**판정: 우리 결정이 맞다 — 다만 Codex 도 반대하지 않았다(조건부 동의).**
근거: `DECISIONS.md` 2026-09-17 행 3개 —
① canonical 은 `/safe/` 로 고정, ② hreflang 은 `x-default` 자기참조만,
③ 언어별 `/xx/safe/` URL 신설은 **기각·보류**(본문이 전부 JS 치환이라 새 URL 들이 서빙하는
원시 HTML 이 넷 다 동일한 한국어 → 중복이 4개 더 늘어난다).

title/description ↔ 렌더 언어 불일치는 **패키지 ⑤절에 우리가 먼저 적어 올린 항목**이고,
Codex 도 새 근거를 보태지 못했다. 이번 커밋의 결함이 아니라 아키텍처의 성질이므로 그대로 둔다.

---

## (c) 오탐 / 해당 없음 — 4건

### C-1. Q1 단서 — "`public_file_server.enabled` 가 꺼진 배포에서는 이 미들웨어도 빠진다"

사실이지만 **이 배포에는 해당하지 않는다.** 반증: `config/deploy.yml:35` → `RAILS_SERVE_STATIC_FILES: true`.
프로덕션은 Rails 가 직접 `public/` 을 서빙하고 앞단 `kamal-proxy` 는 정적 서빙을 하지 않는다.
이 조건은 `config/initializers/static_index_redirect.rb` 주석에 **이미 명시돼 있다**
(가드 `if Rails.application.config.public_file_server.enabled` 포함).

### C-2. Q1 본문 — 경로 누수·파손 없음

Codex 스스로 "깨뜨리는 증거는 보이지 않는다"고 답했다. 실측으로도 확인됨:
Rack 단위 17 케이스(에셋·`/api/`·`/safe/sw.js`·`.webmanifest`·POST 통과),
전체 라우트 16개 스모크 200, 리다이렉트 홉 1회(체인 없음). 지적 아님.

### C-3. Q2 — 301 의 `cache-control: no-cache`

Codex: "SEO상 큰 문제로 보이지 않는다… 목적과 맞다." 우리 판단과 일치. 지적 아님.
근거: `DECISIONS.md` 2026-09-17 "301 응답에 `cache-control: no-cache` 를 붙인다" 행.

### C-4. Q5 — 공허한 단언 없음

Codex: "완전히 공허한 단언은 보이지 않는다." 다만 SW 전환 위험이 테스트 범위 밖이라고 덧붙였다 —
그 부분은 **A-1 로 이미 반영**했으므로 별건으로 세지 않는다. 지적 아님.

---

## 다음 런 작업 목록 (이 문서의 산출물)

| # | 항목 | 위험도 | 파일 |
|---|---|---|---|
| 1 | SW install 에서 `/safe/` 를 필수 자산으로 분리 — 실패 시 install 실패시켜 구 캐시 보존 | AMBER | `public/safe/sw.js` |
| 2 | 301 본문에서 URL 반사 제거(또는 `CGI.escapeHTML`) | GREEN | `lib/static_index_redirect.rb` |

⛔ 둘 다 **이번 세션에서 고치지 않았다.** 배포 전에 처리하는 것을 권한다 — 둘 다 작은 변경이다.
