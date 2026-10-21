# SafeFile JP S7: 콘텐츠 반자동 생산 파이프라인 + 첫 3편 제작. 배포·게시는 하지 말 것.

## 자율 실행 규칙
- 중간 확인 없이 끝까지. 막히면 CLAUDE.md 「JP-1 이슈 로그」에 기록하고 계속. 3-Strike 적용. 시간 약속 금지.
- 기존 골든 전부 유지. public/safe/index.html 탐지 로직 변경 금지.
- 완료 시 커밋(푸시·배포 금지). 마지막 줄 "S7_DONE".

## 읽을 것
docs/jp/jp_safefile_strategy_v2_2026-10-21.md §5·§6 (콘텐츠 원칙·30편 목록), docs/jp/jp_market_decision_v2_2026-10-22.md §4 (제목 수정·추가 3편), docs/jp/jp_landing_copy_2026-10-22.md (톤·금지어), test/safe/run.mjs (Playwright로 /safe/ 를 구동하는 방법), test/safe/fixtures/jp/ (더미)

## 금지 규칙 (모든 콘텐츠)
- 사건명(タイムズカー 등) 불사용 · 1인칭 피해담 불사용 · 「絶対/防ぐ/唯一/必ず安全」 불사용
- 모든 How-to에 「提出先の指示を必ず確認してください」 1줄 포함
- 더미 카드 이미지는 축소 삽화(긴 변 ≤ 800px)로만, 고해상 원본 게시 금지
- 법적 효과는 「制限される場合があります」 수준

## A. 주제 정본
1. `content/jp/topics.json`: 전략 v2 §6의 30편을 시장결정 v2 §4대로 수정(1·14·20번 → 最小化原則 교육형, 신규 3편 추가 → 33편). 각 항목: `{ep, track:"A"|"B", title_ja, title_en, doc, purpose, landing:"nyusatsu"|"honnin"|"aimae", status:"draft"|"ready"|"posted", week}`. 주 1편 기준으로 `week` 1~33 배정. 순서: 1층(사업자)·資格確認書 관련을 앞에, AI 익명화 2편을 4주 안에.

## B. 파이프라인 `scripts/content/make_episode.mjs <ep>`
2. 입력: `content/jp/epNN/post_ja.md`(사람 또는 Claude Code가 쓴 본문, frontmatter에 title·hook·bullets 3개·cta). 출력(같은 폴더):
   - `post_en.md` — 본문 영어판은 **생성하지 않음**(번역은 Claude Code가 C단계에서 직접). 파일이 없으면 경고만.
   - `x_thread.md` — frontmatter의 hook + bullets 3 + cta + 랜딩 URL(UTM `?utm_source=x&utm_campaign=epNN`)로 4~5 트윗 자동 조립(각 140자 이내, 일본어)
   - `carousel_1.png`~`carousel_3.png` — 1080×1350. HTML 템플릿(`scripts/content/templates/carousel.html`, /safe/ 디자인 토큰·IBM Plex Sans KR·Noto Sans JP)을 Playwright로 렌더. 1=title+hook, 2=bullets, 3=cta+URL. 글자 넘침 시 자동 축소.
   - `demo.gif` + `demo.mp4`(가능하면) — track A만. Playwright로 `/safe/?lang=ja&purpose=<purpose>` 를 열어 `doc`에 해당하는 더미(jpg 촬영풍)를 업로드 → 탐지 결과 → 「文書を作成」 → 결과 미리보기까지 프레임 캡처(0.5초 간격, 최대 40프레임), 720px 폭, 하단에 자막 3줄(frontmatter `captions`) 오버레이. 로컬 서버(`bin/rails s` 또는 run.mjs가 쓰는 정적 서버) 사용, 프로덕션 호출 금지.
   - `manifest.json` — 생성 파일·크기·게시 체크리스트(X/YouTube Shorts/Instagram/블로그 각 `posted:false`)
3. `scripts/content/README.md`: 사용법 3줄, 게시 절차(Justin이 manifest의 posted 체크 → topics.json status 갱신).
4. 실패 허용: GIF 생성 실패 시 나머지 산출물은 만들고 manifest에 `demo:"failed:<이유>"`.

## C. 첫 3편 본문 작성 (Claude Code가 직접)
5. ep01·ep02·ep03 의 `post_ja.md`를 topics.json 순서대로 작성(각 600~900자, 블로그용). 구성: hook 1문장 → 왜 문제인가 2~3문장 → 書類別 표 또는 3단계 → 「提出先の指示を必ず確認」 → CTA(해당 랜딩 URL). 톤은 jp_landing_copy 와 동일. `post_en.md` 영어판 동반(의역, 같은 구조).
6. 세 편에 `make_episode.mjs` 실행 → 산출물 생성 → `docs/jp/s7_samples/` 에 carousel_1.png 3장과 GIF 1개 복사(검수용).

## D. 보고
7. `docs/jp/s7_report.md`: 파이프라인 구조, 실행 시간, 실패 항목, 검수 포인트(예: 자막 위치, GIF 길이), 다음 편 만들 때의 명령 1줄.
