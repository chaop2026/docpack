# S8 보고 — 블로그 JA 트랙 + 주간 승인 패키지 + X 자동 게시 + OG/파비콘

시작 2026-10-25 01:24 KST · 종료 2026-10-25 03:30 KST (약 2시간)
브랜치 `main`. **미배포·미푸시·실제 게시 0건.** 프로덕션 DB 미접촉. `X_API_DRY_RUN=1` 고정.

입력: [`s8_prompt.md`](s8_prompt.md) · 정본 [`jp_content_strategy_v3.md`](jp_content_strategy_v3.md)(v3.1) ·
교차검증 [`codex_review_v3_2026-10-25.md`](codex_review_v3_2026-10-25.md)

| 검증 | 결과 |
|---|---|
| `bin/rails test` | **333 runs / 2,200 assertions / 0 failures** (직전 208/1,487) · **연속 8회 동일** |
| `node test/safe/run.mjs` (골든) | **557/557** — 변화 없음 |
| `node test/safe/check_matrix.mjs` | 188 triple + 10 legal pair 일치 |
| `node test/safe/jp_landing_check.mjs` | **128/128** (직전 110) — 3회 연속 |
| `node test/sw/offline_resilience.mjs` | **9/9** |
| `ruby script/canonical_sweep.rb` | **6/6 통과** (중복 200 = 0, 리다이렉트 경유 내부 링크 = 0) |
| rubocop | **86** — 베이스라인과 동일(신규 0) |
| brakeman | 6 → **8** (+2, 아래 §7에 사유) |
| `content:jp_import[1..3]` | 3편 전부 import, guard **clean** |
| 프로덕션 DB | **미접촉** |

---

## 1. E-1 — KO 블로그 색인 신호 회귀 가드 (마이그레이션보다 먼저 만들었다)

`test/integration/blog_seo_snapshot_test.rb` + `test/fixtures/blog_seo_snapshot.json` (**25 항목**).

**canonical 공식을 테스트가 다시 유도하면 뷰와 함께 흘러가도 서로 일치한다** — 공허한 단언의 모양이다.
그래서 포착과 비교가 **같은 코드**로 **같은 행**을 돌고, 신호는 **렌더된 HTML 에서** 뽑는다:
`canonical` · `robots` · `hreflang` 전체 · `og:locale` · `og:url` · `<html lang>` · 그리고 모델 쪽
`indexable_locales` · `indexable?` · `translated?`.

행은 dev DB(3행의 로컬 스크래치)가 아니라 **픽스처**에서 온다 — 프로덕션에 실제로 존재하는 네 모양
(ko 단독 발행 · 이중언어 발행 · draft · scheduled)을 전부 덮고, 모든 머신과 CI 에서 동일하다.

- 공허 방지 3겹: 스냅샷 부재 시 **실패** · 항목 수 하한 16 · URL 집합 **동등**.
- ⚠️ **첫 포착은 순서 의존이었다.** 프리픽스 요청이 심은 `locale` 쿠키가 다음 요청으로 넘어가,
  `/blog/bilingual-published-post` 가 **직전 루프가 /es 였다는 이유만으로** `og:locale=es_ES`·
  `<html lang="es">` 로 기록됐다. 요청마다 `reset!` 로 콜드 세션에서 측정하도록 고치고,
  시드를 바꿔 재포착해 **바이트 동일**을 확인했다.
- **실효성 실측**: `indexable?` 에서 발행 상태 가드를 빼면(= S8 이 막아야 하는 바로 그 회귀) **실패한다.**
  원복 후 녹색.

**결과: 마이그레이션·모델 재작성·라우팅 변경·뷰 분기 전부를 거친 뒤에도 25/25 동일.**

KO 42편의 색인 동작을 지키기 위해 **의도적으로 하지 않은 것**: Article JSON-LD 의 `inLanguage` 를
KO 글에는 넣지 않았다. 넣는 것이 옳지만 「한 글자도 바뀌면 안 된다」가 이번 라운드의 조건이고,
구조화 데이터에 필드가 하나 느는 것은 변경이다. 별도 단계로 분리한다(§8 백로그).

---

## 2. 변경 파일

### 신규 (코드)
| 파일 | 역할 |
|---|---|
| `db/migrate/20261025000001_add_jp_content_track.rb` | ja 컬럼 4 + `primary_locale`(NOT NULL·CHECK) + `(content_track, content_ep)` **부분 unique 인덱스** + `package jsonb` · `blog_topics` 11컬럼 + `(track, ep)` unique. **기존 행이 전부 `ko` 로 백필됐는지 마이그레이션 안에서 assert** |
| `app/services/jp_content_guard.rb` | `guard_rules.json` 의 **서버 쪽 실행기**. 가중 길이 계산기 포함 |
| `app/services/jp_episode_source.rb` | `content/jp/epNN/` 1폴더 = 1객체. frontmatter·FAQ·스레드·LinkedIn 조립·자산·content_hash |
| `app/services/jp_import.rb` | `(jp, ep)` 키 upsert · 경쟁 rescue · **import 가 절대 쓰지 않는 키** merge |
| `app/services/jp_approval.rb` | 承認 트랜잭션 + `approved_version` 지문 + `social_skip` 이월 |
| `app/services/jp_weekly_kpi.rb` | P1/P10/P15/P16/P17/**P18** 한 곳. 주간 산출·승인 화면·검토 메일이 같은 값을 읽는다 |
| `app/jobs/auto_generate_jp_post_job.rb` | 토 00:00 KST 주간 잡 |
| `app/jobs/x_publish_job.rb` | 트윗별 재개 가능한 스레드 게시 |
| `app/controllers/admin/jp_packages_controller.rb` + `app/views/admin/jp_packages/show.html.erb` | 승인 화면 1장 |
| `app/views/blog_mailer/jp_review_requested{,_x_failed,_x_unknown}.html.erb` | 검토 요청 · X 실패 · **X 결과 불명**(별도 메일) |
| `app/views/posts/_jp_article.html.erb` | JA 기사 셸 |
| `lib/x_client.rb` | OAuth 1.0a + `Net::HTTP`. 젬 추가 없음 |
| `lib/jp_markdown.rb` | md → HTML (이 앱에는 마크다운 젬이 없다) |
| `lib/tasks/content.rake` | `content:jp_import[NN]` |
| `content/jp/guard_rules.json` | **규칙 정본** — JS·Ruby 두 엔진이 읽는다 |
| `scripts/content/guard_rules.mjs` | 위 파일의 JS 로더 |
| `scripts/content/add_v31_fields.mjs` | §4 표 → `topics.json` 필드 (일회성, 감사 가능하게 커밋) |
| `scripts/content/shoot_samples.mjs` · `docs/jp/brand/make_og.mjs` · `make_maskable.py` | 보고용 스크린샷 · OG 카드 · maskable 아이콘 |

### 신규 (테스트, 124개)
`blog_seo_snapshot_test`(E-1) · `jp_content_guard_test`(47) · `jp_content_track_test`(20) ·
`x_publish_job_test`(17) · `auto_generate_jp_post_job_test`(14) · `jp_approval_test`(16) · `jp_plan_test`(10)

### 수정
`post.rb` · `blog_topic.rb` · `safe_event.rb` · `posts_controller.rb` · `admin/posts_controller.rb` ·
`blog_mailer.rb` · `blog_generator_service.rb` · `publish_scheduled_posts_job.rb` ·
`auto_generate_blog_post_job.rb` · `posts/show.html.erb` · `posts/index` · `admin/posts/index` ·
`layouts/application.html.erb` · `pages/sitemap.xml.erb` · `routes.rb` · `recurring.yml` ·
`application.css` · `jobs.rake` · `blog.rake` · `safe.rake` · `make_episode.mjs` ·
`jp_landing_check.mjs` · `safe_events_controller_test.rb` · 랜딩 3페이지 · `jp.js` · `sw.js` ·
webmanifest 4개 · `topics.json` · ep01~03 원고 · 전략 v3.1 · 예측 보고서

---

## 3. 설계에서 한 선택 (그리고 왜)

### 3-1. `primary_locale` 은 **선언**이지 추론이 아니다
어느 본문 컬럼이 차 있는지로 추론하면, 두 개가 차는 순간 **canonical 이 입력 순서에 따라 뒤집힌다.**
NOT NULL · CHECK `('ko','ja')` · 기존 행 전부 `ko` 임을 **마이그레이션 안에서 단언**(기본값은 그 기본값이
있던 시점의 행에만 적용된다 — 지금 추가하는 컬럼은 이미 있는 행에 붙는다).

게시 불변식은 **일반화**했지 느슨해지지 않았다: 「발행된 글은 **자기 primary locale** 의 제목과 본문을
가진다」. KO 글에는 `body_ko` 에 대한 같은 조건이고, **에러 메시지도 바이트 동일**이다
(`errors.add(:body_ko, :blank)` → ko.yml 경유 「본문(한국어)을(를) 입력해 주세요」 — 어드민 폼과 발행 실패
메일이 읽는 문자열이라 리터럴로 쓰지 않았다).

### 3-2. `(track, ep)` 는 **DB** 가 보장한다
교차검증 Q2: 「승인한 내용이 한 번 게시됨」은 두 프로세스가 같은 ep 를 집을 수 있는 한 약속할 수 없다
(맥의 월간 import 와 서버의 주간 폴백). 부분 unique 인덱스(`WHERE content_track IS NOT NULL`)로
KO 글은 제약 밖에 두고, JP 만 강제한다.

> 🔴 **테스트가 내 구현의 실제 결함을 잡았다.** `find_or_create_post!` 의 rescue 가
> `RecordNotUnique` 만 잡고 있었는데, **실제 경쟁은 `RecordInvalid` 로 온다** —
> `validates :slug, uniqueness: true` 가 INSERT 전에 SELECT 를 돌려 패배자를 **검증 단계에서** 거부하므로
> 인덱스까지 가지도 않는다. 즉 그 rescue 는 아무것도 잡지 못했다. 둘 다 잡도록 고쳤고,
> **행이 실제로 존재할 때만** 흡수한다(없으면 re-raise — 내용 오류를 조용한 no-op 으로 바꾸지 않는다).
> `AutoGenerateJpPostJob#create_from_generation` 에도 같은 수정.

부수로 확인한 것: `Post.insert` 는 **ON CONFLICT DO NOTHING 으로 컴파일되어 raise 하지 않는다**(실측).
그걸로 쓴 테스트는 인덱스가 있든 없든 초록이다. `create!`(= 실제 호출 경로)로 단언한다.

### 3-3. 승인은 **한 버전을 동결**한다
`approved_version = SHA256(title_ja + body_ja + body_en + x_thread + x_reply_en + linkedin_text +
assets digest + published_at)`. XPublishJob 이 12:00 JST 에 재계산해서 어긋나면 **게시하지 않고 blocked**.

`published_at` 을 지문에 넣은 이유: 월요일로 승인한 패키지를 금요일로 옮기는 것은 **다른 결정**이다.
`view_count` 같은 무관한 저장이 지문을 움직이지 않는 것도 테스트로 고정했다 — 움직였다면
**누가 기사를 읽는 순간 스레드가 스스로를 막는다.**

실측으로 확인됨: 엔드투엔드 드라이런 중 내가 `published_at` 을 승인 **후에** 옮겼더니 X 가 `blocked` 로
멈췄다. 설계대로 동작한 것이고, 내 테스트 조작을 잡은 것이다.

### 3-4. X: **트윗은 두 번 게시되지 않는다**
나머지 전부가 여기서 나온다.

| 실패 | 처리 |
|---|---|
| 4xx 거부(결정적) | 그 seq `failed`, 상태 `partial_failed`, 메일. 재실행은 **거기서부터** |
| 타임아웃·5xx·429 (**결과 불명**) | 그 seq `unknown`, **잡 중단**, 자동 재전송 **없음**, 전용 메일 |
| 미디어 업로드 양쪽(v2·v1.1) 실패 | **텍스트만 게시하지 않는다** — 데모 없는 1트윗째는 아무도 승인하지 않은 다른 게시물이다 |

`tweet_id` 는 API 응답 **즉시** `update_column` 으로 쓴다 — 한 줄 뒤의 크래시가 그 사실을 잃으면 안 된다.
`with_lock` 으로 동시 실행 금지. `unknown` 은 사람이 타임라인을 보고 「送信済みとして記録」(ID 입력) /
「未送信として再開」 중 하나를 고를 때까지 **그 뒤 트윗도 전부 멈춘다**(건너뛰면 4번이 2번에 답글이 되고
3번이 중복될 수 있다).

실측(드라이런, 6트윗): 1→2→3→4→5→6 이 정확히 체인되고 `posted.x=true`·URL 기록.
3번째 실패 후 재실행 → **2건만 전송**(3·4), 1·2 재전송 0건. `unknown` 상태에서 재실행 → **0건 전송**.

### 3-5. 규칙 정본 1개 — `content/jp/guard_rules.json`
규칙이 `make_episode.mjs` 의 JS 상수였기 때문에 **서버는 아무 검사도 하지 않았다.**
JSON 하나를 두 엔진이 읽는다. 정규식은 JS·Ruby 가 모두 컴파일할 수 있는 문법으로만 쓰고, 플래그는
인라인 `(?i)` 대신 필드로 선언한다. **두 로더 모두 시작할 때 전부 컴파일한다** — 컴파일되지 않는 규칙은
조용히 영원히 안 맞고, 그건 「아무것도 못 찾은 가드」와 밖에서 같아 보인다.

### 3-6. 「법적 주장이 있을 때만」 출처를 요구한다
교차검증 Q4: 「모든 글에 施行日 필수」는 **환각을 유도한다** — 파일을 드래그하는 手順 글에는 인용할
법령이 없고, 억지로 붙이면 아무도 확인하지 않은 출처가 생긴다. 조건부다. 그리고
**`go.jp` 가 정규식을 통과한 것은 검증이 아니다** — 사람이 확인 가능한 주소를 주장 옆에 두게 만들 뿐이다.

`法` 의 오탐은 lookbehind 로 막았다(`方法により`·`手法` 이 법령 인용으로 읽히면 모든 手順 글이 URL 을
요구하게 된다 — 테스트로 고정).

---

## 4. 새 가드가 **실제로 잡은** 위반 (ep01~03 전부)

| # | 위반 | 조치 |
|---|---|---|
| 1 | **필수문이 세 회차 모두 문단 중간에 묻혀 있었다** | v3.1 §3-2 ⑤ 가 「본문 독립 행」을 요구하는데 아무도 검사하지 않았다. 독립 행으로 옮김 |
| 2 | **ep01·ep02 가 출처 없이 법적 주장** | 厚生労働省 원문으로 根拠 절을 세움: 健康保険法第194条の2第1項 · 国民健康保険法第111条の2第1項 · 2020-10-01 施行 · `https://www.mhlw.go.jp/stf/newpage_13989.html` (確認日 2026-10-25). **URL 은 지어내지 않고 검색으로 실제 페이지를 확인했다** |
| 3 | **ep03 은 출처 대신 문장을 고쳤다** | 「社内規程や受任契約で…制限されている」는 법이 아니라 계약·사내규정 얘기다 → 「…を認めていないことがあります」. **조건부 규칙의 의도가 이것이다: 법이 아닐 때 법처럼 말하지 않게 한다** |
| 4 | **ep01 1트윗째가 가중 146 > 140** | hook 을 3자 줄임(블로그 부제도 같이 바뀜) |
| 5 | **영어 답글이 세 회차 전부 가중 168~189 > 140** | `x_reply_en` 을 「hook+CTA+URL 조립」에서 **저자가 쓰는 `x_reply:` frontmatter**로 바꾸고 ep01~03 에 작성. 폴백은 **가장 짧은 정직한 조립**(CTA+URL) — 언제나 위반하는 폴백은 가드를 무시하도록 가르친다 |

> ⚠️ **5번은 승인 화면이 먼저 보여줬다.** import 는 `guard: clean` 이라고 했는데 admin 미리보기에
> 6/6 트윗이 ⚠️ 로 떠 있었다 — **가드가 5트윗만 검사하고 잡은 6개를 게시한다**는 뜻이었다.
> 「검사 범위가 게시 범위보다 좁다」는 2026-10-22 와 **같은 결함이 새 장소에 생긴 것**이다. 범위를
> `[*x_thread, x_reply_en]` 로 맞췄다.

### 140 은 **가중** 길이다 (단위 정정)
v3 는 「트윗당 140자(全角2·半角1·URL 23 환산)」라고 썼는데 파이프라인은 **원시 문자 수**를 140 과
비교하고 있었다. 일본어는 가중치가 2 이므로 그 비교는 **허용량을 조용히 두 배로 만든다**(140 CJK = 가중 280).
이제 두 숫자를 **같은 단위**로 재고 이름을 붙여 따로 보고한다 — 140 = 우리 편집 상한, **280 = X 실제 상한**
(넘으면 「투고できません」).

---

## 5. 그 밖에 실측으로 잡은 결함 (전부 이번 세션에서 발견)

### 🔴 D-1. `public/safe/brand/` 가 **프로덕션에서 전부 404 날 상태였다**
디렉터리 권한이 `drwx------`(700, owner `sunghoon`). Dockerfile 은 `USER 1000:1000` 으로 돌고
`COPY . .` 는 권한을 가져간다. **실제 이미지에서 측정**:

```
docker run --user 1000:1000 … ls /rails/public/safe/brand
→ UID1000: NOT READABLE (production would 404 every brand icon)
```

**dev 에서는 보이지 않는다** — dev 컨테이너가 root 로 돌기 때문이다. 즉 파비콘·OG 카드·매니페스트
아이콘이 전부 조용히 404 나고, 로컬에서는 멀쩡해 보였을 것이다. 755/644 로 고쳤다.
(git 은 실행 비트만 저장하므로 신규 클론은 644 다 — 위험 범위는 **이 맥의 작업 트리에서 빌드하는 이미지**,
즉 `kamal deploy` 가 실제로 하는 바로 그것이다.)

### 🔴 D-2. `--no-demo` 재빌드가 **게시 사실을 지웠다**
실측: 가드 변경을 반영하려고 ep01 을 재빌드하니 `posted.x` 가 true→false 로 돌아가고 고정 트윗 URL 이
사라졌다. manifest 가 「스레드는 게시된 적 없다」고 말하게 되는데 이건 **새 작업처럼 읽히는 거짓**이다.
`posted` 는 세상에서 일어난 일의 기록이고 이 스크립트는 그것을 알 수 없다 → 이전 manifest 에서 **이어받는다**.
`demo` 도 산출물이 디스크에 남아 있으면 유지(캐리오버 라벨이 **누적되지 않도록** 접미사 제거도 추가).

### D-3. P16 은 **계산할 차원이 없었다**
`safe_events` 의 `landing_view` 가 허용하는 키는 `from`(랜딩 페이지 슬러그)·`locale` 뿐이다.
「SNS 경유 비중」을 셀 수 있는 것이 없는데, 그대로 두면 **자신 있게 0% 를 보고한다.**
→ `utm_source` 차원 신설(고정 7값 `x|linkedin|youtube|blog|direct|other|none`, 자유 텍스트 0).
`jp.js` 가 `?utm_source=` 를 그 목록에 **매핑해서** 보낸다(그대로 통과시키면 방문자가 고른 문자열이 된다).
`blog` 는 목록에 있고 **P16 분자에서는 제외**한다 — 블로그 자체 CTA 는 내부 링크이고, 세면 블로그가
자랄수록 지표가 올라간다(P16 이 묻는 것의 반대).

⚠️ **이 차원은 2026-10-25 이전 이벤트에는 없다.** 주간 산출에 그렇게 적어뒀다 —
빈 표는 「소셜 유입 0」이 아니라 「이 차원을 보내는 버전이 아직 배포되지 않음」일 수 있다.

### D-4. JA 기사의 **언어 전환기가 자기 자신으로 301** 했다
`canonical_sweep` 이 「리다이렉트 경유 내부 링크」로 잡았다. JA 글에 「한국어」를 제시하면
`/blog/:slug?locale=ko` → 301 → 같은 페이지. 존재하지 않는 언어를 권하는 셈이다.
→ `@switcher_locales` 로 **그 글이 실제로 존재하는 로케일만** 제시(JA 글 = ja·en). 미설정이면 기존 동작.

### D-5. 3열 표의 **세 번째 열이 잘려 있었다**
`white-space: nowrap` + `overflow-x` 라서, 680px 본문 폭에서 「残す」 열이 스크롤바 뒤로 밀렸다 —
**1280px 데스크톱에서도.** 隠す/残す 표의 요점이 두 열의 대비인데 한쪽을 숨기면 안 된다.
→ 셀을 wrap 시키고 `overflow-x` 는 폴백으로만 남겼다(스크린샷으로 3열 확인).

### D-6. 주간 잡의 7일 가드가 **도달 불가**였고, 그 대가가 보이지 않았다
`next_jp` 가 `review_sent_at: nil` 만 고르므로 잡 안의 7일 가드는 정상 경로로 발화할 수 없다.
큐는 **의도적으로 전진한다**(ep05 가 승인되지 않아도 다음 주는 ep06) — 한 회차가 뒤를 막으면 안 되기
때문이다. 대신 **건너뛴 회차가 안 보이게 된다**: `publish_stuck` 은 `scheduled` 만 보는데 미승인 패키지는
`draft` 를 떠나지 않는다.
→ `Post.jp_unapproved_overdue` 신설 + `/admin/posts` 배너 + `rake blog:stuck`(exit 1).
**상태로 드러낸다 — 실패를 보고하는 채널이 실패한 그 채널이면 안 된다**(이 저장소의 기존 원칙).
가드는 남기되 **도달 경로가 좁다는 사실을 주석에 명시**하고, 스코프를 통과한 척하는 테스트 대신
직접 단언한다.

### D-7. 테스트가 잡은 자기 결함 2건
- **병렬 오염**: `tmp/jp_generated/epNN.json` 을 두 테스트가 공유해, 한쪽이 쓴 파일이 다른 쪽의 API 호출을
  건너뛰게 했다(단독 실행 초록, 병렬 에러). `save_dir` 을 `class_attribute` 로 빼 테스트가
  프로세스별 임시 디렉터리를 쓴다. **파일시스템에 손을 넣고 순서를 바라는 것은 seam 이 아니다.**
- **주변 로케일 의존**: KO 에러 메시지 단언이 간헐적으로 실패했다. 실측 — `:en` 에서는 같은 실패가
  「본문(한국어)**공백**을(를) …」로 렌더된다(Rails 기본 `"%{attribute} %{message}"`, ko.yml 은 공백 없음.
  한국어 조사는 명사에 붙는다). S8 이 바꾼 것이 아니라 기존 동작이지만, **주변 상태에 의존하는 단언은
  진짜 회귀를 노이즈로 치부하게 만든다.** `I18n.with_locale(:ko)` 로 고정했다.

### D-8. (기존 테스트) 레이트리밋 테스트가 **분 경계와 경주**하고 있었다
`bucket = Time.current.to_i / WINDOW` 로 버킷을 채운 뒤 요청을 보내는데, 그 사이에 경계를 넘으면
요청은 **빈 버킷 N+1** 에 떨어져 상한이 걸리지 않는다. 실패 모양은 「리미터가 깨졌다」다.
병렬 실행에서 1회 관측 → `travel_to` 로 시간 고정. 리미터는 멀쩡했다.

---

## 6. import 결과 (개발 DB)

```
ep01: Post #18 jp-ep01-how-to-redact-the-numbers-on-a-qualifica  draft
  title_ja 【入札添付】資格確認書の番号を隠して提出する手順
  body_ja 1,513 chars HTML · body_en 3,059 · hero carousel_1.png
  assets  carousel_1..3.png, demo.gif, demo.mp4
  x_thread 5 + 영어 답글 1 · faq 3 · linkedin 591자
  publish_on 2026-10-26 (blog 09:00 JST) · guard clean
ep02: Post #19 jp-ep02-reading-a-tender-s-masking-instructions   draft  publish_on 2026-11-02  guard clean
ep03: Post #20 jp-ep03-redact-the-personal-data-before-you-past  draft  publish_on 2026-11-09  guard clean
```

**멱등 확인**: 재실행 2회 → Post 1개 유지, `created=false`.
**승인 후 재import 실측**: exit **2**, 본문·상태·`approved_version` **변화 0**, `import_conflict` 기록.

스크린샷 `docs/jp/s8_samples/` — `admin_package_ep01..03.png`(승인 화면 전체), `public_ja_article_ep01.png`.

### X 드라이런 로그 발췌 (ep03, `X_API_DRY_RUN=1`)
```
[X DRY RUN] media upload x-media….png (image/png, 101497 bytes)
[X DRY RUN] POST /2/tweets {"text":"AIに契約書の意味を聞くとき…","media":{"media_ids":["dry-media-…"]}}
[X DRY RUN] POST /2/tweets {"text":"①相談に必要なのは条項と金額の関係で…","reply":{"in_reply_to_tweet_id":"dry-a733c154e3eb35c2"}}
[X DRY RUN] POST /2/tweets {"text":"②貼り付けた内容を保存するAIサービスは多く…","reply":{"in_reply_to_tweet_id":"dry-1f786d3442ed341b"}}
[X DRY RUN] POST /2/tweets {"text":"③画像にして貼れば、黒塗りの下の文字列はコピーできません","reply":{"in_reply_to_tweet_id":"dry-7ec99691dcea7556"}}
[X DRY RUN] POST /2/tweets {"text":"契約書をAIに貼る前に…\n提出先の指示を必ず確認してください。\nhttps://…?utm_source=x&utm_campaign=ep03","reply":{…}}
[X DRY RUN] POST /2/tweets {"text":"Before pasting a contract into an AI tool…","reply":{…}}
```

> 🔴 **실제 계정의 요금제·월 쓰기 한도·미디어 업로드 권한을 확인하기 전에는 `X_API_DRY_RUN=1` 을 유지한다.**
> v3 의 「Free = 월 1,500 쓰기」는 교차검증 Q3 에서 **확정 전제가 아님**으로 정정됐다.
> 자동화가 자기 한도를 **소진해서** 알아내면, 그 방식은 스레드를 절반만 올리는 것이다.
> 키가 없으면 코드는 자동으로 드라이런이다(「일단 해보고 본다」로 떨어지지 않는다).

---

## 7. brakeman 6 → 8 (+2) — 전부 기존에 수용한 패턴의 새 위치

| 위치 | 내용 | 판단 |
|---|---|---|
| `admin/jp_packages/show.html.erb:278,286` | `body_ja`/`body_en` 미리보기 `html_safe` | **어드민 전용 + 우리 자신의 생성물**(`JpMarkdown` 이 텍스트를 전부 이스케이프하고 고정 태그 집합만 낸다). 공개 페이지의 `body_ko` 가 이미 같은 등급으로 수용돼 있다 |

FAQPage JSON-LD 의 weak 경고는 **제거했다** — 문자열 보간을 버리고 Ruby Hash → `to_json` 으로 바꿨다.
따옴표·역슬래시·개행이 든 질문이 **조용히** 잘못된 JSON-LD 를 만들던 것도 함께 사라졌다(구글이 그냥 버린다).
적대 문자열(`</script><img src=x onerror=…>`)로 프로브: 블록은 여전히 JSON 으로 파싱되고
`<img>` 는 문서에 **도달하지 않았다**(Rails 가 `escape_html_entities_in_json` 으로 `<`→`<`;
`gsub("</", "<\\/")` 는 그 설정이 꺼져도 유지되는 2차 방어).

---

## 8. Justin 이 할 것

### ① X 개발자 앱 등록 → 키 4개
`.env.production.local` 에 **이름 4개**만 추가(값은 절대 로그·커밋에 남기지 말 것):
```
X_API_KEY
X_API_SECRET
X_ACCESS_TOKEN
X_ACCESS_SECRET
```
그리고 **요금제·월 쓰기 한도·미디어 업로드 권한을 대시보드에서 확인**한 뒤에만 `X_API_DRY_RUN` 을 뺀다.
확인 전까지는 `.env.production.local` 에 `X_API_DRY_RUN=1` 을 **명시**해 두는 쪽이 안전하다.
`XClient.credential_report` 는 값이 아니라 `present?`/`length` 만 돌려준다(테스트로 고정).

### ② 교차검증 1줄
> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
codex exec --sandbox read-only "$(cat docs/jp/codex_prompt_v3.md)" < /dev/null | tee docs/jp/codex_review_s8_2026-10-25.md
```
(`< /dev/null` 필수 — 없으면 `Reading additional input from stdin...` 에서 멈춘다.)

### ③ 배포 전 실기기 확인
> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널 (배포는 Justin 만)

- 🔴 **KO 블로그 임의 3편의 canonical·hreflang·x-default·noindex 를 배포 후 시크릿 창으로 재확인.**
  E-1 은 픽스처 기준이고, 프로덕션 42편의 실물은 배포 후에만 볼 수 있다.
  예: `/blog/resume-privacy` · `/en/blog/resume-privacy` · `/ja/blog/resume-privacy`
  → canonical 이 한국어 주소, `/en`·`/ja` 가 `noindex,follow`, x-default 가 `/blog/…`.
- `/safe/` 파비콘이 **새 로고**로 바뀌었는지(탭 아이콘). 홈 `/` 의 SlimFile 파비콘은 **그대로**여야 한다.
- 랜딩 3페이지 링크를 LinkedIn·X 에 붙여넣어 **미리보기가 새 OG 카드**로 뜨는지.
- `/safe/brand/icon-192.png` 가 **200** 인지 (위 D-1 — dev 에서는 안 보이는 종류의 404).
- `bin/rails blog:stuck` 과 `bin/rails jobs:failed` 가 프로덕션 큐 DB 에서 도는지(S6b 이월 항목).

### ④ 사람 확인 대기
- `public/safe/작업물/` 정체 (CLAUDE.md 이슈 로그). 지금은 `.gitignore`+`.dockerignore` 로 **배포 제외만** 했다.
- ep05·ep06 의 전자입찰 용량 상한·보조금 정산 요령 **근거 미확인** — 본문 쓰기 전에 공고 1건 확인(S7 이월).
- **일본 변호사 검토는 여전히 없다.**

### ⑤ 다음 월간 배치 (ep04~)
> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac, 일반 터미널

```
node scripts/content/make_episode.mjs 4 && bin/rails content:jp_import[4]
```

---

## 9. 남는 공백 (백로그)

| # | 항목 |
|---|---|
| B-1 | **ep04~33 본문 미작성** (33편 중 3편) |
| B-2 | KO 글 Article JSON-LD 에 `inLanguage` 미적용(§1 의 의도적 보류) |
| B-3 | 본문 분량 1,500~2,200자 규칙은 `guard_rules.json` 의 `limits` 에 **값만 있고 강제하지 않는다** — 지금 세 편은 산문 614~783자라 켜면 전부 막힌다(S7 이월) |
| B-4 | `utm_source` 는 **배포 후에만** 쌓인다. 배포일 이전 주차의 P16 은 이 표로 판정하지 말 것 |
| B-5 | LinkedIn 은 수동. `package.posted.linkedin_url` 을 사람이 기록해야 P18 이 센다 |
| B-6 | `make_episode.mjs`·`make_og.mjs` 의 **폰트가 머신 의존**(S6b 이월). 산출물은 커밋돼 있으므로 배포물은 안전하지만, 다른 머신에서 재생성하면 달라진다 |
| B-7 | 1인칭 피해담 금지·더미 카드 ≤800px 은 **정규식으로 판정 불가**(README 에 별도 표로 분리) |
| B-8 | `/safe/jp/` 가 301→404 (S6b 이월) · honeypot 타이밍 · 600/분의 근거 없음 |
| B-9 | `JpMarkdown` 은 의도적으로 좁은 서브셋이다. 원고가 그 밖의 문법을 쓰면 **조용히 평문**이 된다 — 가드가 잡지 않는다 |
| B-10 | ep30(犯収法)·ep32(一括)은 `verify_before`. ep32 는 `blocked_until` 로 **빌드·import 양쪽에서 거부**된다 |

**S8_DONE**
