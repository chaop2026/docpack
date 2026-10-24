# Codex 교차검증 요청 — SafeFile JP 콘텐츠 전략 v3 (블로그 허브 주간 OSMU)

## 이 라운드가 무엇인지

JP-1 알파(탐지·마스킹)와 S6(랜딩)·S7(콘텐츠 파이프라인)이 닫힌 뒤, **콘텐츠 생산·승인·게시 구조**를 정하는 전략 문서 1건을 본다. 코드 변경 없음. 구현은 이 검증 후 `docs/jp/s8_prompt.md`로 한다.

대상: `docs/jp/jp_content_strategy_v3.md`
전제(바꾸지 않는 것): `docs/jp/jp_market_decision_v2_2026-10-22.md` §1~§4, `docs/jp/jp_forecast_report_2026-10-22.md` §6 예측값, `docs/jp/jp_handoff_2026-10-24.md` §1-1
참조 코드(읽기만): `app/jobs/auto_generate_blog_post_job.rb`, `app/jobs/publish_scheduled_posts_job.rb`, `app/models/post.rb`, `app/models/blog_topic.rb`, `app/controllers/posts_controller.rb`, `config/recurring.yml`, `db/schema.rb`(posts), `scripts/content/make_episode.mjs`, `content/jp/topics.json`

---

## 🔴 검토 범위 — 반드시 이 다섯 가지만

이 밖의 지적은 「백로그」 절에만 기록하고 AMBER로 올리지 마십시오.

### Q1. `primary_locale=ja` 도입이 기존 KO 블로그의 색인·불변식을 깨지 않는가
- `Post`의 「published 글은 body_ko 필수」 불변식을 「primary_locale의 본문 필수」로 바꾸는 설계(v3 §1-1 ③).
- `/blog/:slug`(KO 주소)를 ja 글에 한해 `/ja/blog/:slug`로 301 하는 설계(§1-1 ②).
- `indexable_locales`·hreflang·x-default 계산이 KO 글 42편에 대해 **지금과 동일**하게 남는지. 회귀가 생길 조건을 구체적으로 적으시오(예: KO 글의 x-default가 바뀌는 경우).
- `posts_controller.rb`의 noindex 가드 주석(unpublished·fallback)과 충돌하는 지점.

### Q2. 2층 구조(월간 Mac 배치 + 서버 주간 잡)가 「승인 1회」를 실제로 보장하는가
- 서버 주간 잡이 draft를 못 찾을 때의 폴백(§2-1 마지막)이 **같은 ep를 두 번 만들거나**, 월간 배치가 나중에 import할 때 slug 충돌·중복 Post를 만들 수 있는 경로가 있는지. `rake content:jp_import`의 멱등 키(ep 또는 slug)로 충분한지.
- 승인(`status: scheduled`) 이후 월간 배치가 같은 ep를 다시 import하면 무엇이 덮어써지는지.
- `AutoGenerateBlogPostJob`이 「재시도 없음」인 이유(파일 상단 주석)가 jp 트랙에도 그대로 맞는지, 아니면 jp 트랙은 Claude API를 호출하지 않는 경로(import된 draft 승격)이므로 재시도 정책을 달리 해야 하는지.

### Q3. X API 자동 게시(`XPublishJob`)의 실패 모드
- 블로그 게시 성공 후 X 게시가 실패했을 때 상태가 **STATE로 남는가**(기존 `publish_stuck` 철학). 메일만으로 끝나는 설계라면 AMBER.
- 5트윗 스레드 중 3번째에서 실패하면 부분 스레드가 남는다. 재시도 시 중복 게시를 막는 키(각 트윗 ID 기록)가 설계에 있는지.
- 140자 계산(全角2·半角1·URL 23)이 X의 실제 가중치 규칙과 다른 점이 있으면 지적.
- Free tier 제한(월 쓰기 상한·미디어 업로드 v1.1 엔드포인트)이 주 1편 × 6트윗 + 영어 답글에 충분한지.

### Q4. 일본어 글쓰기 규칙서(§3)에 법적·사실 리스크가 남아 있는가
- 금지어 목록이 v2 §5·`make_episode.mjs` FORBIDDEN과 **일치**하는지. 빠진 단어·추가해야 할 단어.
- 「根拠 문단 1개 필수(법령+施行日)」 규칙이 거꾸로 **환각 근거**를 유도하지 않는지. 대안이 있으면 제시(예: 허용 출처 화이트리스트).
- ep30(犯収法 2027-04 개정)·ep32(一括 미출시)의 조건부 처리(§4 하단)가 충분한지.
- 書類名 정식 명칭 규칙에서 틀린 것(資格確認書/被保険者証 경과조치 시점 등)이 있으면 지적.

### Q5. 30편 재배열(§4)과 예측 P15·P16·P17의 정합성
- P15 「2027-01-22까지 3채널 누적 ≥24편」을 「채널별 게시물 수」로 세는 해석이 예측 보고서 표기와 모순되지 않는지. 모순이면 예측값을 수정하지 않고 **새 행으로 추가**하는 문구를 제안.
- 1주차=2026-10-27 시작, 연말·GW 주 X·LI 생략이 P15 계산에 미치는 영향.
- Instagram 보류가 예측 보고서 §9 채널 정의와 충돌하는 지점과, 보수 예측값(0)에 영향이 없다는 v3 주장의 타당성.

---

## 출력 형식

```
## 판정
Q1 GREEN|AMBER|RED — 한 줄 이유
Q2 …
Q3 …
Q4 …
Q5 …

## AMBER/RED 상세
- [Qn] 문제 → 구체적 수정 문장(v3 문서의 어느 절을 어떻게 바꿀지)

## 백로그 (판정에 반영하지 않음)
- …

## 종합
구현(s8)으로 넘어가도 되는가: YES / YES-with-fixes / NO
```

금지: 새 기능 제안으로 범위를 넓히는 것, 가격·채널 결정 번복, 예측값 수정 제안. 코드 수정 금지(읽기만).
