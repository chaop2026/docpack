# 재검증 결과 — S8b (2026-10-25 14:40)

검증자: ChatGPT (GPT-6.1). 입력: x_publish_job.rb·jp_import.rb 수정 후 전문 + s8b_report §1~§2. 대화: https://chatgpt.com/c/6add924c-ec58-83ee-8620-8b4f7c09784b
Claude 독립 확인: RED·AMBER 모두 코드에서 재현 경로 확인(아래).

## 판정
- Q3' **RED** — 크래시·2워커 기본 방어는 됐으나(①②③④ 전부 자동 중복 없음), **새 결함**: `handle_indeterminate`가 `mark_tweet!`과 `write_x!(resume_requested=false)`를 분리해 쓴다. 사이 크래시 → `resume_requested=true`가 남고, `run`의 unknown 가드가 그 플래그로 우회되어 TTL 후 선점 워커가 unknown 트윗을 재게시. `promote_sending_to_unknown!` 동일. `finish!`의 두 번째 `update_column(posted)`은 토큰 조건 없음 → done인데 posted 미기록 상태가 가능하고 자가 복구 안 됨.
- Q2' AMBER — `apply!` 잠금 안 재검사·`:unchanged` 무쓰기·rescue 축소 확인. 승인 함수(`JpApproval#approve!`)가 잠금 안에서 reload 후 지문을 계산하는지 미첨부라 미확정.

## 종합: **NO** (S8c로 닫은 뒤 YES)
수정 지시는 `docs/jp/s8c_prompt.md`. 핵심: unknown 기록 1회 원자 쓰기, `resume_requested` → `resume_seqs[]`로 범위 한정, `finish!` 1회 원자 쓰기, approve! 잠금 확인.
