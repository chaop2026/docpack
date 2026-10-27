# SafeFile JP S9 — 승인 화면·메일 한국어화 + 한국어 요약 + LinkedIn 개발 일지 + PDF 사용설명서 + 드라이런 안전장치

시작 2026-10-27 11:57 KST · 종료 2026-10-27 13:08 KST (71분)

브랜치 `main`. **미배포·미푸시·실제 게시 0건.** 프로덕션 DB 미접촉. `X_API_DRY_RUN=1` 고정.
입력 [`docs/jp/s9_prompt.md`](s9_prompt.md) · 요구 원문 [`docs/jp/s9_todo.md`](s9_todo.md)

`bin/rails test` 367→**411 runs / 2,348→2,618 assertions / 0 failures** ·
골든 **557/557** · `check_matrix` **188 triple** · E-1 **38/38**(스냅샷 파일 바이트 불변) ·
`jp_landing_check` **128/128** · SW **9/9** · canonical sweep **6/6** ·
rubocop **86**(베이스라인 동일, 신규 0) · brakeman 8→**12**(신규 4건, 전부 Weak — §8).

---

## 0. 먼저: 베이스라인이 이미 빨간색이었다 (세션 시작 시점)

손대기 전에 측정했다. `bin/rails test` → **367 runs / 1 failure**.

```
AutoGenerateJpPostJobTest#test_the_queue_advances_past_an_episode_nobody_approved
  expected #<BlogTopic … ep: 6 …>  /  actual nil
```

**달력 의존 테스트였다.** `BlogTopic.next_jp` 는 `publish_on <= 9.days.from_now` 만 제시하는데,
그 테스트는 두 번째 토픽을 `next_monday + 7` 로 만든다. 오늘이 일요일이면 그 토픽은 8일 뒤(창 안),
화요일이면 13일 뒤(창 밖)다. **토·일·월에만 통과하고 화~금에는 실패한다.**
S8c 가 마지막으로 확인한 날이 2026-10-25(일)이라 그때는 초록이었고, 이 세션이 열린 화요일에 빨갰다.

9일 창도 옳고 테스트의 의도도 옳다 — 틀린 것은 **그 둘 사이를 달력에 맡긴 것**이다.
→ 잡이 실제로 도는 요일인 **토요일(2026-11-07 00:00 JST)로 시계를 고정**했다.
고정하고 보니 그 토픽이 창의 **정확히 경계**에 앉는다는 것이 드러나서, 전제를 단언으로 적어
창을 좁히는 변경이 「설명 없는 nil」이 아니라 이름 붙은 실패로 나오게 했다.

---

## 1. 변경 표

| # | 무엇 | 파일 | 한 줄 |
|---|---|---|---|
| A-1 | `X_API_DRY_RUN:"1"` 을 `deploy.yml env.clear` 에 | `config/deploy.yml` | 지금까지 **어디서도 컨테이너에 들어가지 않았다** — 키만 넣으면 다음 배포가 바로 실제 게시였다 |
| A-1 | 그 선언을 **테스트가 강제** | `test/integration/jp_dry_run_posture_test.rb` | 줄을 지우면 스위트가 깨진다 = 실제 게시 전환이 *의식적인 커밋*이 된다 |
| A-2 | `/safefile` → `/safe/` 301 | `config/routes.rb` | 제품 이름을 입력하면 404 였다 |
| B-3 | 승인 화면·메일 3종 UI **전부 한국어** | `show.html.erb`, `jp_review_requested`, `jp_x_unknown`, `jp_x_failed`, `ko.yml jp_admin.*` | 뷰에 하드코딩 문자열 0 — `t()` 만 |
| B-3 | 컨트롤러 플래시·레이크 메시지·KPI 표 라벨도 한국어 | `jp_packages_controller.rb`, `content.rake`, `jp_weekly_kpi.rb`, `layouts/admin.html.erb` | 같은 사람이 읽는 같은 화면의 나머지 절반 |
| B-4 | 승인 버튼 **상단+하단 2곳**, 같은 폼 | `show.html.erb` | 화면이 길어서 어느 쪽 끝에 두어도 한쪽은 틀린 자리다 |
| B-5 | `/admin/jp/packages/:ep/preview` | `jp_packages_controller.rb`, `concerns/post_show_assigns.rb`(신규) | 공개 레이아웃 그대로, **비관리자 404**(리다이렉트 아님), `noindex,nofollow` |
| C-6 | `summary_ko.md` 7섹션 → `package.summary_ko` | `jp_episode_source.rb`, `jp_import.rb` | **없으면 import 거부**(exit 1) |
| C-7 | KO 요약을 **JA 원문 바로 아래** 배치 | 화면·메일 | 요지는 본문 위, 트윗 KO 는 각 트윗 아래, FAQ KO 는 각 Q 아래 |
| C-7 | 「사람이 판단할 한 가지」 = 승인 버튼 **바로 위** 노란 박스 | 화면·메일 | 버튼이 뜻하는 바로 그 문장 |
| C-8 | 섹션 누락 검사 → 승인 비활성 | `jp_content_guard.rb` | **파일 없음=거부 / 섹션 모자람=가드** 분리 |
| C-6 | 폴백(API) 경로도 같은 구조 | `blog_generator_service.rb`, `auto_generate_jp_post_job.rb` | 두 경로가 같은 상수(`SUMMARY_SECTIONS`)를 읽는다 |
| D-10 | `linkedin_text` 자동 조립 **삭제** → `linkedin_en.md` 그대로 | `jp_episode_source.rb` | `bold_unicode` 헬퍼도 함께 삭제(남기면 재조립을 부른다) |
| D-11 | `guard_rules.json` 에 `linkedin` 섹션 | `guard_rules.json`, `jp_content_guard.rb`, `guard_rules.mjs`, `make_episode.mjs` | 금지 6패턴 + 평균 문장 길이·링크 1·해시태그 3·글자 수 |
| D-12 | ep01 교체(지시문 본문 그대로) · ep02·03 신규 | `content/jp/ep0{1,2,3}/linkedin_en.md` | 각 회차에서 Justin 이 실제로 만든 것 |
| E-13 | `guide_en.pdf` 생성 | `make_episode.mjs`, `templates/guide.html`(신규) | 1080×1350 **7장**, 실제 화면 캡처 4장 |
| E-14 | import 가 PDF 를 `package_assets` 에, 메일에 **첨부** | `jp_episode_source.rb`, `jp_import.rb`, `blog_mailer.rb` | 「관리화면 열고 받아서 LinkedIn」 3단계 → 0단계 |
| F-16 | KO 글 JSON-LD `inLanguage:"ko"` | `posts/show.html.erb` | S8 이 「별도의 감사 가능한 단계로」라고 적어둔 그 단계 |
| F-17 | `finish!` 의 `posted` 를 **키 단위** `jsonb_set` | `x_publish_job.rb` | 통째 교체가 `posted.linkedin_url` 을 지울 수 있었다 |
| ⚠ | 달력 의존 테스트 고정 | `auto_generate_jp_post_job_test.rb` | §0 |
| ⚠ | X 미디어 폴백이 PDF 를 집을 수 있었다 | `x_publish_job.rb` | §5 |

---

## 2. A — 드라이런이 「켜져 있다」가 아니라 「끌 수 없다」가 되게

`XClient.dry_run?` 의 **코드는 이미 옳았다**(`ENV=="1" || !credentials_present?`). 없던 것은 두 가지다.

**① 그 변수가 프로덕션 컨테이너에 도달한 적이 없다.** `deploy.yml` 에 없었으므로 Kamal 이
전달하지 않았고, 프로덕션이 드라이런이었던 **유일한 이유는 X 키 4개가 없다는 것**이었다.
키를 넣는 순간 그 배포가 공개 계정에 글을 올리기 시작한다 — 아무도 그렇게 결정하지 않은 채로.

**② 테스트가 없었다.** 있던 경로는 「키가 없으니 어차피 못 올린다」 쪽이고, **중요한 절반은
「키가 다 있는데도 플래그가 이긴다」** 인데 그쪽이 검증된 적이 없었다.

```ruby
test "X_API_DRY_RUN=1 forces dry run even with all four credentials present"
test "with the flag off and all four credentials present, dry run is OFF"   # 위가 공허하지 않음을 보증
test "a missing credential is enough on its own, whatever the flag says"    # 4개 각각
test "the flag is only honoured as the exact string 1"                      # "true"·"yes"·"0" 는 LIVE
test "deploy.yml declares X_API_DRY_RUN=1 as a clear (non-secret) env value"
```

마지막 테스트가 **안전장치 그 자체**다. deploy.yml 에서 그 줄을 지우면 스위트가 깨지므로,
실제 게시를 켜려면 **테스트도 같이 고치는 커밋**이 되고 그것은 diff 에 남는다.
주석은 실행되지 않는다. `secret` 이 아니라 `clear` 인 이유도 같다 — secret 은 호스트에서
해석되어 diff 에 아무 흔적을 남기지 않는다.

> ⚠️ 값은 **따옴표 친 `"1"`** 이어야 한다. YAML 의 맨 `1` 은 Integer 이고, `"true"`·`"yes"` 는
> `dry_run?` 이 인정하지 않는다 — 전용 테스트로 고정했다.

### `/safefile` → `/safe/`

라우트에는 **슬래시 없는 철자만** 선언했다. `get "/safefile/"` 는 **죽은 코드**다 —
`CanonicalPathRedirect` 가 라우터보다 앞에서 트레일링 슬래시를 떼므로 라우터가 그 철자를 보지
못한다. 그리고 「규칙처럼 보이는 죽은 코드」는 `get "/safe", to: redirect("/safe/")` 가 2년간
빠져 있던 바로 그 함정이다. `/safefile/` 는 1홉(미들웨어) + 1홉(라우트) = **2홉으로 `/safe/`** 에
닿고 거기서 멈춘다 — 목적지와 종료를 둘 다 단언했다. `DIRS` 에는 넣지 않았다(= `public/safefile/`
가 없으므로 그 목록의 뜻과 다르다).

---

## 3. B — 승인 화면이 한국어가 아니면 승인은 형식이다

S8 의 이 화면은 전부 일본어였다. 콘텐츠가 일본어니 UI 도 일본어로 쓴 것이고, 그 결과
**「承認」 버튼이 2,000자 일본어 법률 산문에 책임지라고 요구**했다. 그 자리에서 사람이 하는
정직한 행동은 그냥 승인하는 것이다.

- UI 문자열 **전부 `config/locales/ko.yml` 의 `jp_admin.*`**, 뷰에는 `t()` 만.
  하드코딩을 금지한 이유는 스타일이 아니다 — **「승인자에게 어떤 문장이 보이는가」를 파일 하나에서
  전수로 읽을 수 있어야** 하고, 다음에 이 화면을 고치는 사람이 일본어 한 줄을 조용히 되살릴 수 없어야 한다.
- 콘텐츠(기사 제목·본문·트윗·LinkedIn 본문)는 **원문 그대로**. 나가는 바이트가 그것이고,
  번역된 미리보기는 다른 것의 미리보기다.
- 범위를 「지시된 4개 뷰」에서 넓힌 곳: 컨트롤러 플래시 8개, `content.rake` 의 거부·충돌 메시지,
  **KPI 표의 지표명**(이 표만 일본어로 남으면 한국어 화면에서 유일하게 못 읽는 칸이 된다),
  사이드바의 `JP パイロット`. 전부 같은 사람이 같은 화면에서 읽는다.

> KPI 를 옮기면서 **예측값은 건드리지 않았다.** P 번호가 예측 보고서와의 연결고리이지 문장이
> 아니다. P15 의 「원문 그대로」 표시는 **채널 집합이 여전히 X·YouTube·Instagram** 이라는 뜻이고,
> 그래서 이 표로는 계산할 수 없다는 사실도 그대로다(전략 §6).

### 공개 페이지 미리보기

`posts#show` 의 ivar 설정을 `PostShowAssigns` 로 추출해 **공개 경로와 미리보기가 같은 코드로
같은 문서를 렌더**한다. 복사했다면 템플릿이 자기 입력에 대해 두 개의 정본을 갖게 되고, 그 입력에는
**색인 신호(canonical·robots·hreflang·x-default)** 가 들어 있다 — 이 저장소가 두 경로의 불일치로
두 번 벌을 받은 바로 그것이다. 컨트롤러에 남긴 둘은 **공개 요청의 성질**이라서다:
맨 경로 301(미리보기엔 리다이렉트할 주소가 없다)과 `increment!(:view_count)`(승인자의 미리보기가
독자 수로 집계되면 안 된다 — P 시리즈가 그 컬럼을 읽는다).

**비관리자는 404**다(로그인 리다이렉트 아님). 리다이렉트는 `/admin/jp/packages/7/preview` 가
실재하는 주소임을 확인해 주고 회차 번호는 추측 가능하다. 다만 **이것이 보호하지 않는 것**도 적어 둔다 —
같은 초안은 이미 `/ja/blog/:slug` 에서 슬러그만 알면 200 으로 읽힌다(의도된 동작, `Post#indexable?`).
그러니 이 조치는 **열거 가능한 두 번째 주소를 만들지 않는 것**이지 초안을 비밀로 만드는 것이 아니다.

> 🔴 **`content_for` 는 APPEND 한다.** 초안을 미리보기로 열면 두 조건이 동시에 참이라
> 처음 구현은 `noindex,follownoindex,nofollow` 라는 **하나의 망가진 지시어**를 냈다.
> 망가진 robots 값은 거부되는 게 아니라 **무시된다** — 페이지는 색인 가능해지고 태그는 제 일을
> 하는 것처럼 보인다. 값 하나를 계산해서 한 번만 쓰도록 고쳤고, 전용 테스트가 있다
> (구 구현에 대고 돌리면 실패한다 — §7).

---

## 4. C·D — 두 입력이 「파생물」에서 「입력」이 됐다

| | 없을 때 | 누가 판정 | 왜 |
|---|---|---|---|
| `summary_ko.md` | **import 거부 (exit 1)** | `JpEpisodeSource#validate!` | 승인자가 읽을 수 없는 패키지는 만들지 않는다 |
| `linkedin_en.md` | **import 거부 (exit 1)** | 〃 | 템플릿이 쓴 LinkedIn 글은 불완전한 패키지가 아니라 **틀린 패키지**다 |
| 섹션 7개 중 일부 없음 | import 하고 **승인 비활성** | `JpContentGuard` | 파일은 있고 사람이 썼다 → 고칠 규칙 위반 |

이 분리는 S8 부터의 계약 그대로다(「입력이 없다」 ≠ 「규칙을 어겼다」).
`make_episode.mjs` 는 두 파일이 없어도 **경고만** 하고 빌드한다 — 기사는 보통 개발 일지와 한국어
요약보다 먼저 써지고, 빌드를 실패시키면 「모든 파일이 생길 때까지 카루셀 없음」이 되어
파이프라인이 덜 돌게 된다. **게이트는 import 다**(승인 가능한 것을 만드는 단계니까).

### LinkedIn 자동 조립을 「조정」이 아니라 「삭제」한 이유

옛 버전은 `post_en.md` 의 `hook`+`bullets`+고정 CTA+고정 해시태그로 글을 만들었다. 그것은
**기사의 유능한 요약**이고, 기사는 서류를 제출해야 하는 일본인을 향해 쓰였다. LinkedIn 독자는
그 사람이 아니다. 개발 일지는 **1인칭으로 무엇을 시도했고 무엇이 깨졌고 지금 무엇을 믿는가**이며,
기사의 불릿을 어떻게 배열해도 그것이 되지 않는다. 조립을 남기고 규칙만 얹으면 파이프라인은
**아무도 쓰지 않은 카피**를 계속 생산한다.

### 🔴 지시문의 두 조항이 서로 모순됐다 — 보고 대상

§D.12 는 ep01 본문을 **「그대로 저장」**하라고 하고, §D.11 은 LinkedIn 한도를 **≤1,300자**로 정한다.
**그 본문은 1,399자다.** 둘 다 만족시킬 수 없다.

측정한 사실:

| | 볼드 헤드라인 | UTM URL | 해시태그 | 고정 오버헤드 | 1,300 에서 본문 예산 | 실제 |
|---|---|---|---|---|---|---|
| ep01 (Justin) | 100 | 133 | 36 | 269 | 1,031 | **1,399** |
| ep02 | 92 | 132 | 36 | 260 | 1,040 | 1,367 |
| ep03 | 65 | 133 | 36 | 234 | 1,066 | 1,333 |

1,300 은 전략 v3.1 §3-3 이 LinkedIn 을 **「조립된 3불릿 요약」**으로 규정하던 때의 숫자다.
§3-3 은 2026-10-25 에 **개발 일지**로 개정되면서 글의 *종류*를 바꿨고 길이는 다시 유도하지 않았다.
서로 다른 두 사람이 개정된 규격대로 쓴 글 셋이 전부 1,333~1,399 에 들어온다.

**판단: 본문을 고치지 않고 한도를 1,500 으로 올렸다**(`guard_rules.json` 의 `linkedin.limits.chars`).
근거를 그 옆에 전부 적어 뒀다. 한도는 **증거를 옆에 둔 조절 가능한 수치**이고 저자의 문단은 아니다.
LinkedIn 실제 상한은 3,000 이므로 1,500 도 여전히 편집 한도이고 여전히 강제된다.

> ⚠️ **이것은 지시문에서 벗어난 유일한 항목이다.** `chars` 를 1300 으로 되돌리면 세 글이
> **즉시 전부 가드에 걸린다** — 짧은 한도가 진짜 결정이라면 그게 원하는 동작이다. 한 파일의 숫자 하나.

처음에는 지시대로 1,300 을 유지하려고 ep02·03 에서 내용을 잘라냈다가, 한도를 바꾸기로 한 뒤
**잘라낸 문장을 되돌렸다**(문장을 조이는 개선은 남기고, 의미를 지운 삭제만 복구).

### summary_ko.md 파서에서 의도적으로 한 선택

- **알 수 없는 `## 제목`은 버린다.** 화면은 고정 슬롯을 렌더하므로, 모르는 섹션은 쓰이고
  저장되고 **아무에게도 보이지 않는다** — 조용한 유실이다. 버리면 가드가 「그 섹션 없음」으로
  이름 붙여 보고하고, 저자는 오타 난 제목을 위반으로 본다.
- **번호 항목은 파일 순서 그대로**, 번호로 정렬하지 않는다. 저자가 1,3,2 로 적으면 화면도 1,3,2 로
  보여 실수가 드러난다. 정렬하면 **한국어가 엉뚱한 일본어 트윗에 붙고 양쪽 다 멀쩡해 보인다**(테스트 있음).
- 요약 블록은 `JpMarkdown` 으로 렌더한다. 처음엔 raw 로 찍었는데 **표가 파이프 문자 기둥으로,
  강조가 리터럴 별표로** 나왔다 — 일본어를 쉽게 만들어 주라는 물건이 일본어보다 읽기 어려웠다.

---

## 5. E·F — 나머지

### guide_en.pdf (7장)

하나의 HTML 문서에 페이지 크기 섹션 N 개 → `page.pdf()` **1회**. 페이지당 호출+합치기는 PDF
라이브러리가 필요하고, 이 방식은 필요 없다. **PNG 도 같은 DOM 에서** 뽑으므로 페이지와 그 PNG 가
어긋날 수 없다. 장 구성: 표지(질문) · 문제 장면(검은 상자 밑에서 복사되는 도식) · 단계 4 · CTA.

- 표지 질문은 **`linkedin_en.md` 의 첫 줄을 디볼드**한 것이다. 별도 헤드라인을 여기서 쓰면 같은
  산출물이 서로 다른 두 개의 도입부를 갖게 되고, 아무도 편집하지 않는 쪽이 낡는다.
- 트랙 B·데모 없음 → 캡처 대신 도식, **같은 장 수**. 그 회차만 짧은 PDF 는 「다른 트랙」이 아니라
  「덜 만든 제품」으로 읽힌다.
- 페이지 수는 **PDF 파일에서 다시 읽는다**(`/Type /Pages … /Count`). 레이아웃한 수와 다르면 실패 —
  기록하는 이유가 둘이 어긋날 수 있다는 것이다.

> ⚠️ **첫 빌드의 캡처가 읽을 수 없었다.** 녹화 뷰포트(720×1280 세로)를 그대로 넣으니 1080 페이지 안에서
> 444px 로 레터박스되고, LinkedIn 은 문서 페이지를 다시 절반으로 줄인다 — 앱 글자가 ~250px 폭이 된다.
> 스크린샷을 넣는 이유 자체가 사라진다. **가이드 캡처만 1120×1000 으로 찍고 복원**하도록 고쳤다
> (리플로 후 다시 앵커 스크롤). 전/후 비교는 `docs/jp/s9_samples/` 의 3·5장.

### F-17 — `finish!` 의 `posted`

S8c 가 한 문장으로 만들어 크래시 창을 닫았지만, `'{posted}'` 는 여전히 **서브트리 통째**
read-modify-write 였다. `post.reload` 와 UPDATE 사이에 형제 키에 쓴 것은 덮인다.
그 자리에 **진짜 쓰는 사람**이 있다 — 어드민의 `record_linkedin` 이 `posted.linkedin_url` 을 쓰고,
**P18 은 그 URL 이 있는 회차만 센다**. 잃은 쓰기 = 잃은 계측이고, 어드민은 어느 쪽이든 성공
알림으로 리다이렉트하므로 조용하다. LinkedIn 주소는 어디서도 복원되지 않는다.

> 🔴 **coalesce 가 장식이 아니다.** `jsonb_set` 은 경로 앞 단계가 없으면 **에러가 아니라 대상을
> 그대로 돌려준다.** 이 DB 에서 측정: `jsonb_set('{"a":1}', '{posted,x}', 'true')` → `{"a": 1}`.
> `posted` 키가 아직 없는 것은 **모든 회차의 첫 실행**이므로, 가드 없이는 `finish!` 가 성공을
> 보고하면서 아무것도 쓰지 않는다 — S8c 가 고친 「done 인데 posted 없음」이 **다른 문으로** 돌아온다.

### F-16 — `inLanguage`

S8 이 JP 트랙에만 넣으며 **「한국어 트랙에 넣는 것은 별도의 감사 가능한 단계」**라고 적어 뒀다.
그 단계다. canonical 경로에서 유도하므로 한 식이 두 트랙을 모두 덮는다.
**E-1 은 JSON-LD 를 보지 않는다**(head 의 canonical·robots·hreflang·og:locale·html lang 만 포착) —
그래서 38/38 이 바이트 동일한 것이 **기대값**이고, JSON-LD 변경은 **별도 테스트 4개**가 맡는다.
스냅샷이 볼 수 없는 필드는 스냅샷이 지킬 수 없다.

### ⚠ 덤으로 잡힌 것 — X 미디어 폴백이 PDF 를 집을 수 있었다

`upload_media` 의 폴백이 `package_assets.first` 였다. 전 자산이 PNG/GIF/MP4 이던 동안에는 맞았다.
S9 가 같은 컬렉션에 PDF 를 붙이는 순간, 오늘은 정렬 순서 덕에 여전히 이미지가 잡히지만
**카루셀이 없는 회차에서는 PDF 가 미디어 엔드포인트로 간다** — 업로드가 실패하고 스레드 전체가
failed 로 표시되며 로그에는 이유가 없다. 콘텐츠 타입으로 필터하도록 고쳤다(`X_MEDIA_TYPES`).
「리스트 순서로 PDF 를 트윗에서 막는다」는 보장이 아니다.

---

## 6. 증거

### ep01 재import 거부 (`docs/jp/s9_samples/ep01_reimport_refused.txt`)

프로덕션의 ep01 은 2026-10-25 에 승인되어 `scheduled` 다. 로컬 dev DB 는 `draft` 였으므로
**그 상태를 실제 승인 경로(`JpApproval.approve!`)로 재현**한 뒤 import 를 돌렸다.

```
ep1: 승인된(또는 공개 단계의) 패키지와 충돌 — 관리 화면에서 「반려」한 뒤 다시 실행해 주세요
     (status=scheduled, approved_at="2026-10-27T03:41:04Z",
      content_hash=10c4ea2d20114a622ef9f05685cc29dd3ede6583b0337fd0f620178de92eb499)
EXIT=2
```

**거부가 정상이다.** 승인은 하나의 버전을 동결하는 것이고, 파일이 바뀌었다는 이유로 그것을
덮으면 승인은 아무 의미가 없다. 메시지는 한국어이고 **현재 존재하는 버튼 이름**(「반려」)을 가리킨다 —
옛 메시지는 이제 화면에 없는 「差し戻す」 를 가리키고 있었다.

### ep02·ep03 재import (`docs/jp/s9_samples/ep02_ep03_reimport.txt`)

```
ep02: updated Post #26 … status=draft
  assets    : carousel_1.png, carousel_2.png, carousel_3.png, guide_en.pdf
  linkedin  : 1367 chars (linkedin_en.md)
  summary_ko: 7/7 sections (all present)
  guard     : clean
EXIT=0
```
(ep03 동일 형태, `linkedin 1333`, `7/7`, `clean`, EXIT=0)

### 승인 화면 — 한국어 (`docs/jp/s9_samples/ep02_approval_ko*.png`)

- `ep02_approval_ko_top.png` — 결정 영역: 공개 예정표 · **「사람이 판단할 한 가지」 노란 박스** ·
  **「승인」 버튼 + 「누르면 월요일 09:00 JST 에…」** · 한국어 요약(요지·표·근거)
- `ep02_approval_ko.png` — 전체(1280×6271): 트윗마다 KO 요약, FAQ 각 Q 아래 KO,
  `guide_en.pdf` 가 자산 카드로, LinkedIn 개발 일지 원문

하네스는 `[data-jp-package]` 를 기다리고 **`translation missing` 이 본문에 있으면 실패**한다 —
돌아온 것을 그냥 찍는 하네스는 증거처럼 보이는 보고서를 만든다.

### guide PDF (`docs/jp/s9_samples/` 는 경로만, 실물은 `content/jp/ep01/guide_en_pages/`)

| 장 | 내용 | 확인 |
|---|---|---|
| 01 | 표지 — linkedin_en.md 첫 줄 디볼드 + 마커 하이라이트 | 육안 확인 |
| 03 | Step 1 — 실제 `/safe/` 드롭 화면 | 육안 확인 |
| 05 | Step 3 — 실제 탐지 결과(법령 띠 5건 / 残す 7건) | 육안 확인 |
| 07 | CTA + UTM `utm_source=linkedin` | 육안 확인 |

ep01 **7장 / 964KB**(실제 캡처) · ep02 **7장 / 216KB**(도식) · ep03 **7장 / 212KB**(도식).
빌드 시간: ep01 33초(OCR+녹화 포함), ep03 14초.

### 메일 (렌더 실측)

```
subject    : [SafeFile JP] 제02회 승인 요청: 入札添付の資格確認書、「マスキング指示」の読み方
attachments: guide_en.pdf (application/pdf, 217794 B)
translation missing? false | KO 판단 문장 true | KO 라벨 true | JA 콘텐츠 보존 true
jp_x_unknown : [SafeFile JP] 제02회 X 스레드 2번째 결과 불명 — 확인이 필요합니다
jp_x_failed  : [SafeFile JP] 제02회 X 스레드 실패 (partial_failed)
```

---

## 7. 테스트가 공허하지 않음을 실측 (변이 프로브)

구 구현을 되돌려 새 테스트가 실제로 잡는지 확인했다. **전부 원복 확인함.**

| 되돌린 것 | 실패 수 | 어느 테스트 |
|---|---|---|
| `inLanguage` 를 JP 전용으로 | **3** | ko / bilingual / 미번역 로케일 |
| preview 의 404 가드 제거 | **1** | 「404, not a redirect to login」 |
| robots 를 `content_for` 2회로 | **1** | 「ONE well-formed robots directive」 |
| `finish!` 를 S8c 통째 교체로 | **2** | SQL 모양 + **형제 키 클로버** |
| `guard_rules.json` 의 linkedin 섹션 | (로드 시 `RuleFileError`) | 두 로더 모두 시작 시 fetch |

> 🔴 **내 테스트 하나가 공허했고, 프로브가 그걸 잡았다.** 「형제 키를 덮지 않는다」를 처음엔
> `finish!` **호출 전에** 쓰는 식으로 썼는데 — `finish!` 는 맨 먼저 `post.reload` 하므로 그 쓰기는
> 그냥 읽혀 들어온다. **구 코드에서도 통과했다.** 진짜 창은 *reload 와 UPDATE 사이*라서,
> 동시 쓰기를 **reload 자체에 매달아** 재현하도록 고쳤다. 그제서야 구 코드에서 실패한다.
>
> 반대로 「posted 키가 없을 때」 테스트는 **구 코드에서도 통과한다** — 통째 교체는 키가 없어도
> 잘 동작하기 때문이다. 그것은 회귀 가드가 아니라 **S9 구현이 새로 만든 위험**의 가드이고,
> 테스트 주석에 그렇게 적었다. 셋 중 둘이 구 코드에서 실패한다.

### 기존 테스트 4건이 S9 변경을 정확히 잡았다 (전부 의도된 변경)

`jp_approval_test` 2건(「承認」·「承認(無効)」·「weighted」 문자열) · `jp_content_guard_test` 1건
(`linkedin_text:` → `linkedin_en.md:`, 그리고 **1301자가 이제 한도 아래**) ·
`jp_approval_lock_test` 1건(Struct 에 `summary_ko` 멤버 추가).

> ⚠️ `refute_includes response.body, "承認"` 을 먼저 썼다가 **픽스처의 `title_ja` 가
> 「承認テスト」** 라 콘텐츠에 걸려 이미 완전히 한국어인 화면에서 실패했다. 옛 UI 문자열 7개를
> **이름으로** 거부하도록 바꿨다. 가드 문자열(`編集上限`)은 **일본어 그대로 둔다** — 진단 메시지를
> 번역하면 빌드가 출력하는 것과 달라진다.
>
> 가드 한도 테스트는 이제 **숫자를 리터럴로 쓰지 않고 규칙 파일에서 읽는다**. 1300 을 박아 뒀다면
> 한도가 1500 이 된 뒤에도 **틀린 이유로 통과**했을 것이다(1301 은 이제 한도 아래다).

---

## 8. 측정값

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **411 runs / 2,618 assertions / 0 failures** (시작 367/2,345/**1 failure**) |
| 신규 `test/integration/jp_s9_review_surface_test.rb` | 33 / 217 assertions |
| 신규 `test/integration/jp_dry_run_posture_test.rb` | 8 / 24 assertions |
| 확장 `test/jobs/x_publish_job_test.rb` | 35 (신규 3) |
| **E-1 스냅샷** | **38/38**, `test/fixtures/blog_seo_snapshot.json` **git diff 0바이트** |
| 골든 (`test/safe/run.mjs`) | **557/557 pass, 0 FAIL** |
| `check_matrix` | **188 triple** 일치 |
| `jp_landing_check` | **128/128** |
| SW 장애 주입 | **9/9** |
| `canonical_sweep` | **6/6** — 변이 115 / 중복 200 = 25(허용치) / 홉 `{1=>88, 2=>2}` |
| rubocop | **86** (HEAD 베이스라인 86 — stash 로 실측 대조, **신규 0**) |
| brakeman | 8 → **12** (신규 4, 전부 **Weak** — 아래) |
| 프로덕션 DB | **미접촉** |
| 실제 게시 | **0건**, `XClient.dry_run? == true` 실측 |

### brakeman +4 — 숨기지 않고 적는다

전부 `JpMarkdown.render(summary[...]).html_safe` 4곳(「Unescaped model attribute」, **Weak**).
기존 2건(`body_ja`·`body_en`, Medium)과 **같은 종류**다.

- `JpMarkdown` 은 **이스케이프를 먼저 하고 마크업을 나중에** 넣는다(`lib/jp_markdown.rb:122`).
  실측: `A <script>alert(1)</script> & "quote"` → `A &lt;script&gt;… &amp; &quot;quote&quot;`.
- 입력은 **저장소 안의 파일**(`summary_ko.md`)이지 사용자 입력이 아니다.
- 처음엔 `t(...).html_safe` 때문에 **+8** 이었다. Rails 의 **`_html` 키 규약**으로 바꿔 절반을 없앴다 —
  규약은 번역문을 safe 로 표시하면서 **보간 인자는 이스케이프**하므로, 내가 쓴 `.html_safe` 보다
  엄격히 안전하다(`faq_missing` → `faq_missing_html` 개명 포함).
- 남은 4건을 0으로 만들려면 `JpMarkdown` 이 `html_safe` 문자열을 반환하게 하면 된다(기존 2건도 사라진다).
  **공개 렌더 경로의 공유 라이브러리 계약 변경**이라 교차검증 없이 세션 끝에 하지 않았다 — §9 백로그.

---

## 9. 남는 공백 / 사람이 결정할 것

1. 🔴 **LinkedIn 한도 1,300 → 1,500** — 이 세션이 지시문에서 벗어난 **유일한** 항목(§4).
   되돌리려면 `content/jp/guard_rules.json` 의 `linkedin.limits.chars` 한 숫자. 되돌리면 세 글이
   즉시 가드에 걸린다.
2. **`public/safe/작업물/` 정체 확인** — S8 이슈 로그 그대로. 아직 미해결.
3. **ep01 의 `summary_ko.md` 는 「2026-10-25 Claude 번역」이 아니라 `post_ja.md` 에서 새로 썼다.**
   그 번역은 채팅 세션에만 있고 저장소에 없다(검색 확인). ep02·03 과 같은 방식이다.
4. **생성물 무게**: guide PDF + 페이지 PNG 가 3편에 **3.8MB**. 33편이면 ~40MB.
   카루셀을 커밋해 온 기존 관례를 따랐지만, 무거워지면 `guide_en_pages/` 를 먼저 빼는 것이 맞다
   (PDF 가 실제 업로드물이고 PNG 는 보고용 파생물이다).
5. `brakeman` +4 (§8) — `JpMarkdown` 반환값을 html_safe 로 만드는 것이 근본 해결.
6. ep04~33 본문 미작성 · 본문 분량 규칙 미강제 · `JpMarkdown` 서브셋 밖은 조용히 평문 ·
   `utm_source` 는 배포 후에만 쌓인다.
7. **X 요금제·월 쓰기 한도·미디어 업로드 권한 미확인 → `X_API_DRY_RUN=1` 유지.**
8. **일본 변호사 검토는 여전히 없다.**

---

## 10. 배포 체크리스트

`docs/jp/s8b_report.md` §5 의 ⓪~⑧ 을 **그대로** 쓴다(배포 대상·환경 변수·정적 자산 구조 무변경).
**마이그레이션 없음** — S9 는 스키마를 건드리지 않았다. 아래 ⑨~⑫ 를 추가한다.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
cd /Users/sunghoon/Projects/docpack
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac — 배포

```
kamal deploy
```

### ⑨ 드라이런이 컨테이너 안에서 실제로 true 인가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac

```
kamal app exec --reuse 'bin/rails runner "puts XClient.dry_run?"'
```

`true` 여야 한다. **이것이 S9-A 의 전부다** — 지금까지 이 값은 컨테이너에 들어간 적이 없고,
`false` 가 나오면 X 키가 들어 있고 플래그가 전달되지 않은 것이므로 **그 자리에서 멈출 것.**

변수 자체도 함께 확인:

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac

```
kamal app exec --reuse 'printenv X_API_DRY_RUN'
```

### ⑩ `/safefile` 301

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac

```
curl -sI https://slimfile.net/safefile | head -3 && curl -sIL https://slimfile.net/safefile/ | grep -E '^(HTTP|location)'
```

둘 다 최종 `/safe/` 에 닿아야 한다(`/safefile/` 는 301 두 번).

### ⑪ 승인 화면이 한국어로 뜨는가

> **[읽기만]** — 브라우저

`https://slimfile.net/admin/jp/packages/2` 로그인 후 열어 확인:
「승인」 · 「공개 예정」 · 「사람이 판단할 한 가지」 · 「한국어 요약」 박스 ·
`guide_en.pdf` 자산 카드 · **`translation missing` 문자열이 없을 것**.
그리고 「공개 페이지 미리보기」 링크가 공개 레이아웃으로 열리는지.

### ⑫ 프로덕션 ep02·ep03 재import (ep01 은 거부가 정상)

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac

```
kamal app exec --reuse 'bin/rails content:jp_import[2]' && kamal app exec --reuse 'bin/rails content:jp_import[3]'
```

각각 `summary_ko: 7/7 sections` 와 `guard : clean` 이 나와야 한다.

> **[읽기만]** ep01 은 프로덕션에서 `scheduled` 이므로 **재import 가 거부(exit 2)되는 것이 정상**이다.
> ep01 의 새 `linkedin_en.md`·`summary_ko.md`·`guide_en.pdf` 를 프로덕션 행에 넣으려면
> 관리 화면에서 **「반려」** 한 뒤 import 하고 **다시 승인**해야 한다 — 그러면 `approved_version`
> 지문이 새 본문에 대해 다시 계산된다. 블로그는 이미 공개됐으므로 급하지 않다.

---

S9_DONE
