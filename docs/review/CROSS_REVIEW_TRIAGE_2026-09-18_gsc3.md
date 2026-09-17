# 교차검증 대조(triage) — GSC 실제 URL 3건 + Codex 신규 2건

- 대상 커밋: `a504e39` (브랜치 `fix/blog-indexing-signals`, **미배포**)
- 외부 모델 출력 원문: [`CODEX_RESULT_2026-09-18_gsc3.md`](CODEX_RESULT_2026-09-18_gsc3.md)
- 투입 패키지: [`CODEX_REVIEW_PACKAGE_2026-09-18_gsc3.md`](CODEX_REVIEW_PACKAGE_2026-09-18_gsc3.md)
- 직전 라운드: [`CROSS_REVIEW_TRIAGE_2026-09-17_amber2.md`](CROSS_REVIEW_TRIAGE_2026-09-17_amber2.md)
- 🔴 **이 세션에서는 새 (a) 를 고치지 않았다.** 아래 3건은 **다음 수정 런의 입력**이다.

## 결론

| 항목 | 판정 | 우리 대조 |
|---|---|---|
| N-1 JSON-LD 가 canonical 과 다른 문서 지칭 | **해소됨** | 동의 — `body_en` 채운 실측으로 확인 |
| N-2 `body_en` 만 있는 발행 글 | **해소됨** | 동의 — 모델 검증 + 단위 테스트 |
| B-404 `/api/safe_scan` 대응 | **적절** | 동의 |
| B-중복 트레일링 슬래시 + `/en/about` | **적절** (단 신규 1 확인 필요) | 동의 — 확인했다, 아래 참조 |

지적 2건 + Q1~Q7 답변 7건 = **9건 전부 분류했다.** 그중 Q5 가 **새 (a) 1건**을 끌어냈다.

---

## (a) 진짜 문제 — 3건

### N-A. 정적 디렉터리 밑의 **반복 슬래시**가 미들웨어를 빠져나간다 — **GREEN**

**Codex 지적**: `[논리 오류][확신도 낮음]` `path.start_with?("#{dir}/")` 가 `/safe//` 도
"asset underneath" 로 보고 통과시킨다.

**재현했고, 지적보다 넓다.** 바이트 단위로 동일한지까지 확인:

```
 200  /safe/            bytes=129584  md5=d52dec97
 200  /safe//           bytes=129584  md5=d52dec97   ← 동일
 200  /safe///          bytes=129584  md5=d52dec97   ← 동일
 200  /privacy//        bytes=7006    md5=242f514a   ← 동일
 200  /safe//index.html bytes=129584  md5=d52dec97   ← /safe/index.html 의 301 규칙까지 우회
 200  /safe//sw.js      bytes=8979    md5=81d8b697   ← 에셋도 마찬가지
 301  /about//          -> /about                    ← 라우팅 페이지는 정상
 301  //                -> /                         ← 루트도 정상
```

즉 정적 디렉터리 밑으로는 **무한한 중복 URL 가족**이 열려 있다
(`/safe//`, `/safe///`, `/safe//index.html`, `/safe//sw.js`, …).
`ActionDispatch::Static` 이 반복 슬래시를 같은 파일로 정규화해 주는 탓이다.

**GREEN 인 이유**: 이런 철자를 링크하는 곳이 없어 발견 확률이 낮다(내부 링크 102개 전수 확인,
0건). 다만 방금 사이트 전체에서 없앤 것과 **정확히 같은 종류의 결함**이고, 남겨두면
"트레일링 슬래시는 정리했다" 는 기록이 거짓이 된다.

**예상 수정 범위** (다음 런): `lib/canonical_path_redirect.rb` 의 `canonical_target` —
디렉터리 분기 전에 `path.squeeze("/")` 로 반복 슬래시를 먼저 접고, 달라졌으면 그 결과로 301.
테스트는 위 표를 그대로 단언으로 옮긴다(`/safe//`·`/safe//index.html`·`/safe//sw.js` 포함).

---

### N-B. `PublishScheduledPostsJob` 이 새 검증에 걸리면 **배치 전체가 멈춘다** — **AMBER**

**출처**: Codex 가 Q5 에서 "`PublishScheduledPostsJob` 코드는 패키지에 없어 배치가 예외를
삼키는지/전체 중단되는지는 판단 불가" 라며 **경로를 요청**했다. 우리가 확인했다.

**코드로 확인함** — `app/jobs/publish_scheduled_posts_job.rb`:

```ruby
Post.scheduled_ready.find_each do |post|
  post.update!(status: "published")   # ← rescue 없음
  BlogMailer.post_published(post).deliver_later
end
```

`update!` 는 검증 실패 시 `ActiveRecord::RecordInvalid` 를 던지고, `rescue` 가 없으므로
**그 배치의 나머지 글이 전부 발행되지 않는다.**

**이것은 이번 커밋이 만든 결과다.** 검증 전에는 본문 없는 글이 *발행돼 버렸고*(잘못이지만
배치는 계속됐다), 검증 후에는 *발행을 막되 뒤따르는 글까지 막는다*. 정확성은 올라갔고
가용성은 내려갔다. 트레이드오프를 인지하지 못한 채 바꾼 것이므로 (a) 로 센다.

**현재 촉발 조건이 있는지는 알 수 없다** — `body_ko` 없는 `scheduled` 글이 있어야 하는데,
프로덕션 DB 를 건드리지 않기로 했으므로 예약 글의 본문 유무를 확인할 방법이 없다.
라이브 사이트맵은 발행 글만 보여준다. `BlogGeneratorService` 가 한국어를 먼저 쓰므로
가능성은 낮다고 보지만 **추정이며, 추정으로 판정하지 않는다.**

**예상 수정 범위** (다음 런): 잡을 글 단위로 복원력 있게 만든다 —
`rescue ActiveRecord::RecordInvalid => e` 로 그 글만 건너뛰고 로그를 남긴 뒤 계속.
검증과 무관하게 원래 그랬어야 하는 모양이다(메일 전송 실패도 같은 문제를 안고 있다).
배포 **전에** 처리하는 편이 안전하다.

---

### N-C. 미들웨어가 `public_file_server.enabled` 에 묶여 있다 — **GREEN (현재 무해, 확인함)**

**Codex 지적**: `[논리 오류][확신도 보통]` 프록시가 정적 파일을 서빙하는 구성에서는
라우팅 페이지의 트레일링 슬래시 정규화까지 통째로 빠질 수 있다. 경로 요청:
프로덕션 기준 `bin/rails middleware`.

**요청받은 것을 실행했다** — 프로덕션 환경으로 미들웨어 스택을 실제로 뽑았다:

```
RAILS_ENV=production RAILS_SERVE_STATIC_FILES=true  → use CanonicalPathRedirect  ✅
RAILS_ENV=production (변수 미설정)                  → use CanonicalPathRedirect  ✅
```

둘 다 들어간다. `config/deploy.yml:35` 이 `RAILS_SERVE_STATIC_FILES: true` 이고,
Rails 8 에서는 변수가 없어도 `public_file_server.enabled` 가 기본 참이다.
**현재 배포에서 이 미들웨어가 빠지는 경로는 없다.**

**그럼에도 (a) 로 두는 이유**: 가드의 *근거*가 낡았다. 원래는 정적 디렉터리만 다뤘으니
"Static 이 없으면 할 일도 없다" 가 맞았지만, 지금은 `/about/`·`/blog/…/`·`/sitemap.xml/`
같은 **라우팅 페이지**도 고친다. 그쪽은 Static 과 아무 관계가 없다. 언젠가 정적 서빙을
nginx 로 옮기면 정본 URL 정규화가 **아무 신호 없이** 사라진다 — 이 저장소가 반복해 당한
"조용한 실패" 모양 그대로다.

**예상 수정 범위** (다음 런): `config/initializers/canonical_path_redirect.rb` 의 조건 제거.
미들웨어는 Static 에 의존하지 않고 리다이렉트만 하므로 무조건 삽입해도 된다.
삽입 위치만 `insert_before(ActionDispatch::Static, …)` 대신 Static 유무에 따라 고르면 된다.

---

## (b) 의견 차이 — 0건

이번 라운드에는 없다. Q1~Q7 중 판단이 갈린 항목이 없었다.

---

## (c) 오탐 / 해당 없음 — 6건

### C-1. Q1 — 경로 커버리지
Codex: "Propshaft/Active Storage `/rails/...`, `/up`, `/admin`, `.webmanifest`, `/api/` 는
큰 문제가 보이지 않습니다." 우리 실측과 일치(66경로 스윕 + 내부 링크 102개, 이상 0).
덧붙인 두 빈틈은 N-A·N-C 로 반영. 별건으로 세지 않는다.

### C-2. Q2 — 2홉 수용
Codex: "판단은 옳습니다… slug 표를 미들웨어로 옮기면 라우트가 죽은 코드가 되는 위험이 더 큽니다."
우리 결정(DECISIONS.md 2026-09-18)과 **근거까지 일치**. 지적 아님.

### C-3. Q3 — robots.txt vs X-Robots-Tag
Codex: "robots.txt Disallow 가 맞습니다… noindex 는 크롤을 요구하므로 원인 대응과 어긋납니다."
우리 판단과 일치. 지적 아님.

### C-4. Q4 — `/about` 처리와 x-default 생략
Codex: "구분은 옳습니다… 이 페이지는 다국어 선택지가 아니라 단일 영어 문서입니다."
우리가 ⑤-2 에 "확신 없음" 으로 올린 항목인데 독립적으로 같은 결론이 나왔다. 지적 아님.

### C-5. Q6 — JSON-LD 전수 확인
Codex: "검증됩니다. 블록은 `WebApplication`, `FAQPage`, `Article` 3개이고 page identity URL
필드는 2개뿐입니다." 우리 주장이 독립적으로 확인됐다. 지적 아님.

### C-6. Q7 — 공허한 단언
Codex: "뚜렷하게 보이지 않습니다… 실제 301/Location/홉 수를 봅니다… JSON parse 후 비교합니다."
지적 아님. 비어 있다고 한 두 곳(`/safe//`, 배포 스택)은 N-A·N-C 로 반영.

---

## 이번 라운드 자체 평가

- 직전 라운드의 패키지 결함(라우트를 잘라 넣음)을 고쳐 **전문 투입**했다. 이번 "경로 요청"은
  1건(`PublishScheduledPostsJob`)뿐이었고, 그 요청이 **가장 값진 발견(N-B)** 을 끌어냈다 —
  패키지에 잡·서비스 계층을 넣지 않은 것이 이번 패키지의 빈틈이다. 다음엔 포함한다.
- **직전 세션의 추정 3건이 전부 틀렸다는 사실**이 이번 라운드의 방법을 바꿨다: 모든 판정에
  라이브 HTTP 또는 코드 인용을 붙였고, 프로브가 리다이렉트를 따라가 200 처럼 보이던 초기
  측정은 폐기하고 다시 쟀다.

## 다음 런 작업 목록 (이 문서의 산출물)

| # | 항목 | 위험도 | 파일 |
|---|---|---|---|
| 1 | `PublishScheduledPostsJob` 을 글 단위로 복원력 있게 (배치 중단 방지) | AMBER | `app/jobs/publish_scheduled_posts_job.rb` |
| 2 | 반복 슬래시(`/safe//`, `/safe//index.html`, `/safe//sw.js`) 정규화 | GREEN | `lib/canonical_path_redirect.rb` |
| 3 | 미들웨어 삽입 가드에서 `public_file_server.enabled` 의존 제거 | GREEN | `config/initializers/canonical_path_redirect.rb` |

⛔ 전부 **이번 세션에서 고치지 않았다.**
**1번은 배포 전에 처리하는 편이 안전하다** — 이번 커밋이 만든 트레이드오프다.
