# S9 할 일 (2026-10-25 저녁, 배포 후 Justin 지시·발견 누적)

1. **`config/deploy.yml` env에 `X_API_DRY_RUN` 추가** — 지금은 `.env.production.local`의 값이 컨테이너에 안 들어감(`dry_run_env: nil`). 키가 없어 자동 드라이런이지만, X 키 4개를 넣는 순간 바로 실제 게시가 되는 구조. **키 추가 전에 반드시.**
2. **승인 메일·승인 화면에 한국어 섹션** — Justin이 내용을 이해하고 승인할 수 있어야 함. 월간 배치에서 Claude Code가 `post_ja.md`와 함께 `summary_ko.md`(제목 번역·본문 요지·표 번역·근거 1줄·트윗별 KO·FAQ KO·「사람이 판단할 한 가지」)를 쓰고, import가 `package.summary_ko`로 넣고, `jp_review_requested` 메일과 `/admin/jp/packages/:ep`에 JA 원문 바로 아래 표시. 서버 폴백(API 생성) 경로만 API 번역.
3. **LinkedIn = 개발 일지(dev log)** — `jp_episode_source.rb#linkedin_text`의 자동 조립(hook+bullets+CTA)을 폐기. 저자가 쓰는 `content/jp/epNN/linkedin_en.md`를 읽고, 없으면 import 거부(가드 위반이 아니라 입력 누락). 규칙은 전략 v3.1 §3-3 LinkedIn 행(2026-10-25 개정): Justin 1인칭, 이번 주 만든 것·설계 결정·배운 것, SafeFile은 맥락으로만, 「써보고 피드백 달라」 1문장, 링크 1, 해시태그 3. 금지: 일본인 대상 광고 문장, 기능 나열, 브랜드 화법, CTA 2개 이상. `guard_rules.json`에 LinkedIn 전용 금지 패턴 추가(`SafeFile helps|lets you|日本の`, 「free for the first」 류 세일즈 문구).
4. ep01은 `linkedin_en.md`를 손으로 써 둠(1,286자). ep02·03도 S9에서 같은 형식으로 작성 후 재import(미승인 draft라 갱신 허용).
5. KO 글 Article JSON-LD `inLanguage`(S8 보류 항목).
6. `finish!`의 `posted` 서브트리 통째 교체 → 키 단위 `jsonb_set`(S8c 재검증 잔여 AMBER).
7. 랜딩 OG 미리보기 LinkedIn·X 실물 확인(Justin, 배포 후).
