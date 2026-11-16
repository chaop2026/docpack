# QA — ep01 (2026-11-16)

검사기: `node scripts/content/qa_video.mjs 1 2026-11` (커밋됨 · 재실행 가능)
규칙: [`video-qa` 에이전트 정의](../../../.claude/agents/video-qa.md) 6갈래
— ⚠️ 그 파일은 `~/.claude/agents/video-qa.md` 로 **저장소 밖**에 있다(공용 에이전트).

## 실행 결과

```
① guard      : 0 violation(s) — 11 surface(s) × 22 rules = 242 checks
   must-line : 0 violation(s) over 4 surface(s)
② specs      : shorts.mp4 1080×1920 30.00s  OK
             : thumbnails 5/5 at the declared size
             : safe-area violations 0 over 5 file(s)
③ link rules : 0 violation(s) over 2 unclickable surface(s)
             : end card = thumb_short_a.png + 「プロフィールのリンクから」 @29.5s
             : via values {youtube, yt_long} — 0 the server would reject
             : long-form CTA = via=yt_long, no ep  OK
④ boundary   : 40 changed path(s); deploy/secret files touched: 0
⑤ exposure   : 0 introduced over 40 text file(s) (9 modified + 31 new);
               1 carry a pre-existing address, untouched
⑥ vacuity    : surfaces 11 · spec_checks 6 · thumbnails 5 · via_values 2 ·
               unclickable_surfaces 2 · files_scanned 40 — all > 0

판정: 통과 — 모든 항목 ✅
```

## 🔴 첫 실행은 **보류**였다 — 잡힌 것 2건 + 검사기 결함 2건

통과가 처음부터 나온 것이 아니라 **무엇이 잡혔는지**가 이 문서의 요점이다.

### 진짜 결함 (고쳤다)

1. **`pinned_comment_ja.md`** — 필수 문장이 독립 행이 아니었다
   (`隠す範囲は提出先によって違います。提出先の指示を必ず確認してください。` 한 줄).
   규칙은 「자기 행 + 「。」로 끝남」이고, 문단 중간에 섞인 문장은 **안내가 아니라
   카피로 읽힌다**(가드 정본의 `must_line._note`).
2. **`channel_about_ja.md`** — 같은 결함. 두 파일 다 줄을 나눴다.

### 검사기 결함 (고쳤다 — 검사를 약화시키지 않고 **범위를 정확히**)

3. **파일 전체를 읽어 금지어 4건**(`絶対`·`唯一`·`必ず安全`·`防ぎ`)을 냈는데,
   **전부 「이 단어를 쓰지 마라」고 적어둔 주석**이었다. 공개되는 것은 ``` 블록 안뿐이다.
   → 세 템플릿에 **같은 경계**를 적용하고 `content/jp/channel/README.md` 에 규칙을 한 번 적었다.
   ⚠️ 경계가 파일마다 다르면 **어떤 파일은 검사되지 않는데 결과는 「위반 0」으로 똑같이 보인다.**
4. **노출 검사가 「변경」이 아니라 「저장소」에 질문하고 있었다.** `public/safe/jp/jp.js`
   의 연락처 주소를 지적했는데, 그것은 **HEAD 에 이미 있던** 랜딩 페이지의 공개 연락처다
   (`git diff` 로 확인: 이번 변경이 추가한 줄에 `@` 0건). 수정 파일은 **추가된 줄만**,
   새 파일은 전체를 본다.

그리고 실행 중에 `git status --short` 파싱 결함이 하나 더 드러났다 —
고정 오프셋 `slice(3)` 이 경로의 첫 글자를 먹어 `app/models/…` 가 `pp/models/…` 가 됐다.
**ENOENT 로 시끄럽게 죽어서** 발견됐다. 조용히 아무것도 스캔하지 않았다면 초록이었다.

## 판정의 근거가 되는 숫자

| 항목 | 수 | 왜 이 수인가 |
|---|---|---|
| 검사한 면 | **11** | 쇼츠 제목·설명 · 썸네일 문구 3 · 쇼츠 구간 텍스트 · 채널 3 · 긴 영상 2 |
| 게시되는 면 | **11** | 같다. 「검사 범위 < 게시 범위」가 이 저장소의 재발 결함이라 둘을 함께 센다 |
| 금지어 검사 | **242** | 11면 × 22규칙 |
| 규격 검사 | **6** | 영상 1 + 썸네일 5, 전부 **파일에서** 읽음(ffprobe·IHDR) |

## 결정 대기 — 쇼츠 설명란의 URL 2개

QA 가 매 실행마다 ⓘ 로 **출력하지만 판정에는 반영하지 않는** 항목이다.

| | |
|---|---|
| 사실 | `shorts_desc_ja.txt` 에 URL 2개(`くわしく:` · `試す:`)가 있고, **쇼츠 설명란은 눌리지 않는다** |
| 선언 | `config/video_team.yml` 의 `unclickable_link_surfaces` 에 `shorts_description` 이 있다 |
| 그런데 | `test/integration/jp_shorts_test.rb:111` 이 **모든 회차의 설명란에 `?via=youtube&ep=` 링크가 있을 것을 단언한다**(S10 결정) |

즉 **규칙과 테스트가 서로 반대**다. 교차검증(2026-11-16)이 「선언하고 강제하지 않는
규칙은 규칙이 아니다」라고 옳게 지적했고, 그 지적대로 **조용히 면제하지도, 조용히
지우지도 않았다.**

지우지 않은 이유: 이건 실수가 아니라 **더 오래된 결정**이다. 바꾸면
① 커밋된 8편의 설명란 ② **이미 게시된 ep01 영상의 설명** ③ 그 테스트
— 셋이 함께 움직인다. 이번 지시서의 범위는 **고정 댓글과 긴 영상 설명란**이었다.

**판단 재료** (사람이 결정):

- 지울 근거: 눌리지 않는 줄 알면서 `くわしく:` 로 시작하면 **아무 데도 가지 않는 CTA** 다
- 남길 근거(원래 둘 중 하나는 **이미 무효**):
  - ⓐ 읽고 손으로 친다 — 70자 URL 에는 비현실적
  - ⓑ 긴 영상 설명란으로 복사할 원문 — ~~유효~~ **무효**. `make_longform.mjs` 가
    이제 자기 템플릿에서 생성한다(2026-11-16)
  - ⓒ 설명란은 검색에 색인된다 — 약하지만 사실

→ 기울기는 **지우는 쪽**이다. 지운다면 `--text-only` 모드를 만들어 8편의 설명만
다시 쓰면 되고(영상 재렌더 불필요), 그 테스트를 「URL 없음 + 프로필 유도 문장 있음」
으로 뒤집는다. **결정 한 줄이면 실행은 짧다.**

## 이 QA 가 **확인하지 못한 것**

- **썸네일이 좋은지.** 규격·글자수·안전영역·금지어만 본다. 클릭률은 측정 대상이 아니다
- **영상을 끝까지 본 사람이 이해하는지.** 구간 길이와 텍스트 유무만 본다
- **업로드 후의 상태.** 프로필 링크 1번이 랜딩인지, 「관련 동영상」이 걸렸는지는
  브라우저에서 사람이 본다([`youtube_upload_checklist.md`](youtube_upload_checklist.md))
- **계측이 실제로 도착하는지.** `?via=yt_long` 이 서버 화이트리스트에 있다는 것까지만
  확인했다. **배포 전에는 이벤트가 쌓이지 않는다** — 빈 표는 「유입 0」이 아니다
