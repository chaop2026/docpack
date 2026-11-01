# 교차검증 — S10 (2026-11-01 14:40) → YES-with-fixes, Claude 확인 후 필수 수정 2건

검증자: ChatGPT (gpt-5-thinking, Medium). 입력: s10_report + jp.js/app/guard diff + make_episode·gen_demo_docs 발췌 + jp_attribution_test. 대화: https://chatgpt.com/c/6ae6ce31-37a8-83ee-891e-01f7f3cc9254
입력 파일: docs/jp/private/codex_input_s10.md (gitignored)

## ChatGPT 판정 (5건 전부 AMBER → YES-with-fixes)
| Q | 판정 | 요지 |
|---|---|---|
| Q1 P16 분모 | AMBER | 분모 수정 확인. 단 `SafeEvent::KEYS`가 via·utm_source 둘 다 허용 → 둘 다 실린 행은 이중 집계 가능 |
| Q2 보안 | AMBER | diff 범위에 XSS·리다이렉트 없음. sanitize 전체·컨트롤러 미첨부라 미검증 |
| Q3 가드 동등성 | AMBER | 두 로더 동일 규칙. `x_opener_feature`가 「無料だと思って契約したら…」 같은 피해 서술도 차단(오탐) |
| Q4 Shorts 검증 | AMBER | ffprobe가 파일을 읽음(자기보고 아님). 비교 코드 미첨부라 미검증. 마스킹 3곳 = 영상 품질 보장은 아님 |
| Q5 더미 안전 | AMBER | 4종 불변 비교 구현 미첨부. 전화·계좌번호가 실존값과 우연 일치 가능 |

## Claude 실코드 확인 (Mac 저장소)
- Q1: 실제 결함. `SafeEvent.sanitize`는 키별 허용만 하고 **상호배타를 강제하지 않는다**. jp.js는 둘 다 보내지 않지만 서버가 막지 않음 → **수정 1**.
- Q2: `sanitize`는 KEYS·VALUES 밖이면 `nil`(전체 거부). 저장 폭주 없음. → GREEN, 수정 불요.
- Q3: 오탐 지적은 타당하나 규칙 의도(기능어로 시작 금지)와 충돌. 가드를 바꾸지 않고 전략 §3-3 비고에 「피해 서술이 無料 등으로 시작하면 어순을 바꿔라」 1줄 추가 → 수정 3(문서).
- Q4: `make_episode.mjs` 1092~1103행에서 폭·높이·길이 비교 후 불일치 시 throw. → GREEN.
- Q5: **실제 결함.** `gen_demo_docs.py` 428행이 `os.listdir` 결과(파일명)만 비교 → 내용이 바뀌어도 통과. sha256 내용 비교로 교체 → **수정 2**. 전화번호는 `090-0000-NNNN` 대역으로 고정(미할당 블록), 계좌는 `0000NNN`.

## 종합
**YES-with-fixes — 수정 1·2(코드) + 3(문서)을 S10b로 처리 후 푸시·배포.** 배포 후 실측: 랜딩 1회 방문 후 `rake blog:jp_kpi` 주간 표에 via 열이 생기는지.
