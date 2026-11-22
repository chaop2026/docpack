# 작업 지시서 — SafeFile JP 제작 보드에 썸네일·영상 채우기 + 야간 런 연결 (2026-11-22)

> 실행 위치: **Justin의 Mac · Claude Code**
> 작업 폴더: **`/Users/sunghoon/Projects/docpack`** (단, 4번은 `/Users/sunghoon/Projects/newVideoGen-v1.19.0`)
> 결과 보고: `docs/autorun/AUTORUN_<YYYY-MM-DD>.md` (저녁 보고 예약 작업이 이 파일을 읽는다)

---

## 0. 배경 (이것만 알면 된다)

- 정본 보드: Notion **「SafeFile JP 제작 보드」**
  - https://app.notion.com/p/420a6f5c15d581bc9ec6d12df3f44ee0
  - data source `collection://420a6f5c-15d5-810b-9bd4-000bc3002daf`
  - 영상 1편 = 카드 1장. 단계: 기획 → 콘티 → 제작 → 썸네일 → 검수 → 승인 대기 → 예약됨/게시됨
  - Justin은 토요일에 **「승인 대기」** 카드만 보고 승인 체크, 「Justin 요청」 칸에 수정 요청, 또는 반려한다.
- 게시된 것은 **ep01 하나뿐**이다(11-22 Justin 확인). ep02~04는 게시되지 않았다.
- **게시 일정은 보드가 정본이다**(11-22 재편성):
  - 가이드: 월요일 — ep02 11/30 · ep03 12/7 · ep04 12/14 · ep05 12/21 · ep06 12/28 · ep07 1/4 · ep08 1/11 · ep09 1/18
  - 사건: 목요일 — #01 12/3 · #02 12/10 · #03 12/17 · #04 12/24 · #05 12/31 · #06 1/7 · #07 1/14 · #08 1/21 · #09 1/28 · #10 2/4 · #11 2/11
- 첫 승인일은 **11/28(토)**이다. 그날 ep02(11/30)와 사건 #01(12/3)이 「승인 대기」에 있어야 한다.
- Justin이 원하는 것: **카드를 열면 썸네일과 영상이 바로 보여서** 승인·요청·반려를 그 자리에서 할 수 있어야 한다.
- 지금 빠진 것:
  - 가이드 ep02~08은 썸네일이 없다(`thumb_ja.json`·`thumb_short_*.png` 없음). 쇼츠는 11-16 끝 화면이 들어가기 **전의 옛 버전**이다(ep01만 다시 만들었다).
  - 사건 #01~11은 영상은 있지만 썸네일이 없다.
  - 어느 카드에도 썸네일·영상 파일이 붙어 있지 않다.

## 1. 일정 동기화 (먼저 · 5분)

- `content/jp/topics.json`의 ep02~09 `publish_on`을 위 보드 날짜로 고친다. ep10 이후는 ep09 다음 월요일부터 한 주씩 민다.
- 커밋: `git add content/jp/topics.json && git commit -m "content(jp): 게시 일정 보드 기준으로 재편성"`

## 2. 가이드 ep02~08 — 썸네일 + 쇼츠 다시 만들기 (게시일 가까운 순: ep02 → ep03 → …)

회차마다 다음 순서로 한다:

1. `video-thumbnail` 에이전트로 `content/jp/epNN/thumb_ja.json`을 쓴다.
   - ep01의 `thumb_ja.json`을 견본으로 삼는다.
   - **2~4단어 질문형 + 「내 일이다」 신호**(서류명이 보이게)로 쓴다. 이유는 `docs/jp/video_*.md`에 있다.
2. `node scripts/content/make_thumbnail.mjs N --only=short` → `thumb_short_a.png`, `thumb_short_b.png`
3. 쇼츠를 끝 화면이 든 버전으로 다시 렌더한다(ep01과 같은 `make_short` 경로). 그 뒤 `qa_video`를 통과시킨다.
4. 보드 카드에 붙인다(5절 방법).
   - `썸네일` 칸: a·b 두 장
   - 카드 본문: 쇼츠 mp4 + 「썸네일 a/b 차이 한 줄」 + 「사람이 판단할 한 가지」
5. 카드 단계를 바꾼다: 단계 → **승인 대기**, 검수 결과 → 통과/반려, 담당 → Justin

🔴 **ep02와 ep03은 11/27(금)까지 끝낸다.** 나머지는 그다음 주로 넘어가도 된다.

## 2-1. 썸네일 후크 규칙 + 고정 댓글 (Justin 요청 11-22 · 가이드·사건 공통)

**썸네일은 단순하게 만든다.**
- 서류 한 장(또는 사건 장면 하나) + **큰 글자 2~4단어 질문** + 빨간 가림 막대 하나. 그 이상은 넣지 않는다.
- 질문은 보는 사람이 「내 서류에도?」 하고 멈추게 만들어야 한다. 예:
  - 「その写し、番号見えてない?」
  - 「黒塗り、本当に消えてる?」
  - 「静岡県警 / 何が漏れた?」
- 쇼츠는 피드에서 **첫 1초**가 썸네일 역할을 한다. 그래서 첫 프레임도 같은 질문으로 시작하는지 확인한다.

**고정 댓글 초안을 카드마다 만든다**(`content/jp/epNN/pinned_comment_ja.txt`, 사건은 `output.nosync/thumbs/story-NN_comment.txt`).
- 채널 본인 계정이 쓰는 고정 댓글 1개. **3줄 이내**로 쓴다:
  1. 영상 내용을 한 줄로 보충한다(例: 「マイナンバーは裏面だけ隠せばOK、ではありません」)
  2. 사이트로 오는 길: 「無料で試すなら → プロフィールのリンク、または『SafeFile 黒塗り』で検索」. 도메인은 글자로만 적는다. 랜딩 URL과 `?via=yt_comment`는 `content/jp/channel/upload_default_description_ja.md`의 정본을 따른다.
  3. 답글을 부르는 질문 하나(例: 「どの書類で迷いましたか?」)
- 🔴 쇼츠 댓글의 링크는 **눌리지 않는다**(2026-11-01 확인). 그러니 「검색어」와 「프로필 링크」 안내가 본체이고, URL은 보조다.
- 🔴 **다른 계정으로 쓴 댓글이나 가짜 시청자 댓글은 만들지 않는다**(YouTube 정책 위반이고, 걸리면 채널이 위험하다). 채널 본인 고정 댓글 1개만 쓴다.
- 카드 본문에 댓글 초안을 붙여 Justin이 승인 때 함께 본다. 실제 게시는 업로드할 때 사람이 한다.

## 3. 비용 · 안전 규칙

- 새 이미지·영상 **유료 생성은 하지 않는다.** 썸네일은 앱 화면 캡처와 글자로만 만든다.
- 업로드·YouTube 예약·게시는 **하지 않는다**(사람이 한다). 승인 체크도 건드리지 않는다.
- `git push`와 배포는 하지 않는다.
- 커밋은 **경로를 지정해서만** 한다(`git add content/jp docs/jp docs/autorun`). `git add -A`는 금지한다.
- `.env` 값은 출력하지 않는다.

## 4. 사건 #01~11 — 썸네일 (작업 폴더 `/Users/sunghoon/Projects/newVideoGen-v1.19.0`)

- 편마다 1080×1920 표지를 2안씩 만든다. 재료는 `output.nosync/safefile-story-NN-verify/scene-*.png` 중 가장 강한 장면 + 2~4단어 질문 + 사건명이다.
  - 예: 「静岡県警 / 何が漏れた?」
- 실명 기관·기업(#08 RIZAP 등)은 **사실로 보도된 표현만** 쓰고, 단정·조롱 표현은 쓰지 않는다.
- 파일은 `output.nosync/thumbs/story-NN_{a,b}.png`에 둔다.
- 보드 카드에 붙인다(5절).
  - `썸네일` 칸: a·b
  - 본문: JA 최종 mp4
- 귀 검수가 끝나기 전이므로 단계는 **검수**에 둔다. 「사람 확인」 칸의 🔴 귀 검수 표시는 지우지 않는다.

## 5. Notion에 파일 붙이는 방법

1. Notion MCP의 `notion-create-file-upload`(filename) → 돌려받은 `upload_url`에 `curl -F file=@...`로 POST한다.
2. 그 다음:
   - 이미지: `notion-update-page` properties `썸네일: [{"type":"file_upload","file_upload":{"id":...}}]`
   - mp4: 응답의 `suggested_markdown`을 카드 본문에 `insert_content`
3. 파일당 20MB 이하. 지금 파일은 전부 그 안이다.
4. 막히면(MCP 없음, 네트워크 거부 등): 파일 경로를 카드 `작업 폴더` 칸에 적고 보고서에 「Notion 첨부 실패: 이유」라고 남긴다. 우회 경로는 만들지 않는다.
   - 참고: 클라우드 세션에서는 api.notion.com 업로드가 프록시에 막혔다(11-22). Mac에서 시도할 것.

## 6. 야간 런 연결 (2·4절이 한 번 돈 뒤)

- 본보기는 `~/Projects/naeilalbum/agents/promo/night_run.md`와 `scripts/promo/night_run.sh`(launchd, 화·수 23:00)다. 이것을 docpack용으로 옮긴다:
  - 잠금 파일은 **덮어쓰기**로 한다(지우지 않는다).
  - 「Justin 요청」 카드를 먼저 처리한다. 「요청 처리」를 새 요청 → 반영 중 → 반영됨으로 옮긴다.
  - 대상: 게시 예정이 다음 토요일 승인 + 7일 안인 카드. 단계 ∈ 콘티·제작·썸네일·반려.
  - 순서: `video-story` → `video-thumbnail` → `video-production` → (분리된 세션에서) `video-qa`
- launchd plist 등록은 **Justin이 직접 한다.** 등록 명령만 보고서에 적는다.

## 7. 끝나면

`docs/autorun/AUTORUN_<YYYY-MM-DD>.md`에 다음을 적는다:

- 처리한 카드 수
- 붙인 썸네일·영상 수
- 실패와 이유
- 🔴 Justin 확인이 필요한 것

그리고 커밋한다(경로 지정).
