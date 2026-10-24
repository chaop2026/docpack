# 교차검증 결과 — JP 콘텐츠 전략 v3 (2026-10-25)

검증자: ChatGPT (GPT-6.1, 웹검색 사용) — Codex CLI는 이 세션의 연결 셸에서 보이지 않아 ChatGPT 웹으로 대체. 입력: `docs/jp/codex_prompt_v3.md` + 전략 v3 전문 + 코드 발췌(post.rb·posts_controller.rb·recurring.yml·make_episode.mjs 가드·예측표 §6/§9).
대화: https://chatgpt.com/c/6adcd8ab-c8b0-83ee-82d5-b210fc9eca9e

## 판정
Q1 AMBER — JA 정본 도입은 가능하지만, 기존 KO의 canonical·x-default 유지 조건과 title_ko 필수 검증 처리가 빠져 있다.
Q2 AMBER — ep 단위 고유성·승인 후 재import·폴백 동시 실행 규칙이 없어 「승인한 내용이 한 번 게시됨」을 보장하지 못한다.
Q3 AMBER — 실패 상태 보존 의도는 있으나 트윗별 재개 설계가 없고, Free 요금제·글자 수 전제가 부정확하다.
Q4 AMBER — 금지어 검사와 규칙서가 불일치하며, 근거 검증·조건부 게시·보험증 유효기간 표현을 보완해야 한다.
Q5 AMBER — P15의 채널 정의를 그대로 계승한다는 주장은 성립하지 않으며, 날짜·휴일 운영 규칙도 서로 충돌한다.

## AMBER 상세 (요지 — 원문은 위 대화)
- [Q1] primary_locale 기존 행 ko 확정·NULL 금지. KO 글의 URL·canonical·indexable_locales·hreflang·x-default 불변. indexable = published AND 해당 로케일 본문 존재(본문 존재만으로 바꾸면 unpublished noindex 원칙과 충돌). draft·scheduled는 noindex·hreflang 빈 목록. `validates :title_ko` 도 primary locale 기준으로. generate_slug가 KO 제목 사용 → JA는 import에서 slug 명시.
- [Q2] 식별자 (track=jp, ep) DB unique. slug는 최초 생성 후 고정. import·폴백은 동일 식별자로 원자적 생성(충돌 시 기존 재조회). `used`와 「주간 검토 대상 선정」을 혼용하지 말 것(.next가 unused만 고르면 import된 ep가 건너뛰어짐). 재import는 미승인 draft만 갱신, approved_at·scheduled·published는 덮어쓰지 않고 충돌 보고. 승인 = 본문·파생물·자산·시각을 하나의 버전으로 고정, 수정 시 승인 무효화 후 재승인. X 전달 대기 상태를 영속화(enqueue 실패도 미전달로 남김). 재시도: import 경로는 제한 재시도, API 폴백은 생성 결과 재사용.
- [Q3] X 상태 = 대기·진행·부분실패·완료·결과불명. 트윗별 순번·본문 해시·응답 ID·부모 ID 즉시 저장, 마지막 확인 성공 다음부터 재개, 동시 실행 금지, 응답 유실 건은 확인 전 재전송 금지. stuck 판정은 X 예정 시각 기준. **X 한도는 가중 280**(CJK 2·URL 23) — 140은 자체 편집 제한임을 명시, twitter-text 기준 검증. 필수문 분리로 6트윗 가능 → 고정 5 전제 제거. **Free 월 1,500 쓰기는 확정 전제가 아님**(현행 사용량 과금, Legacy Free 구분) → 실제 요금제·쓰기 한도·미디어 업로드 권한 확인 후 자동화, 미충족 시 Chrome 게시.
- [Q4] 금지 규칙 단일 소스(문서·로컬·서버): 사건명, 防ぐ 활용형 전부, 完全に/100%, 복수 파일·일괄 우회 표현(JA/EN), 필수문은 독립 행·문장부호까지. 根拠: 「모든 글에 시행일 필수」는 환각 유도 → 법적 주장에만 e-Gov·관할 부처 원문 URL+조항+확인일, 조작 설명 글에는 법령 강제 금지, 확인 불가면 게시 보류, 도메인 화이트리스트 통과=검증 아님. ep30: 게시 4주 전+승인 시점 재확인, 미확인 시 예약 금지, 제목의 「犯収法改正」를 실제 대상 규정과 연결(금융청은 2027-04-01 전후 확인 방법 구분). ep32: 一括 출시 확인 전 보류, 그 주는 ep33. 서류명: 資格確認書와 資格情報のお知らせ 구별, 종전 보험증은 최장 2025-12-01까지 유효·12-02부터 사용 불가, 健康保険被保険者証를 전 보험 단일 명칭으로 쓰지 말 것.
- [Q5] P15 원문(X·YouTube·Instagram 3채널) 보존, **새 행 P18** 추가: 「2027-01-22, 블로그·X·LinkedIn 채널별 실제 게시 누적 ≥24(블로그 JA/EN=1, X 스레드+영어 답글=1, LinkedIn=1, URL·시각으로 확인)」. P18은 P15 대체 실적이 아님. **2026-10-27은 화요일** → 월요일 운영이면 전 표를 하루 앞당김(ep01=10-26, ep10=12-28, ep28=05-03). 연말·GW는 블로그만, X·LI 다음 주 이월, 「X만」 표기 삭제. Instagram 보류 「영향 없음」은 증거 초과 → 운영 가정 변경으로 기록, P16은 블로그 자체 유입 제외, P17은 YouTube 실제 조회만.

## 백로그
FAQPage 노출 요건, OG·파비콘, 미커밋·배포 제외, LinkedIn·YouTube API 쿼터 검증.

## 종합
**YES-with-fixes.** 위 문구를 전략 v3와 s8 구현 조건에 반영한 뒤 진행. 첨부만으로는 KO 42편 무회귀·승인 후 보존·X 무중복을 보장했다고 판정할 수 없음(→ s8 E-1 스냅샷 테스트가 그 증빙).

## 반영 (Claude, 2026-10-25)
전부 수용. v3 §1-1·§2-1·§2-2·§2-3·§3·§4·§5·§7 및 s8 §B·§C·§E 수정. 구체 변경은 각 문서의 「v3.1 변경」 표시 참조.
