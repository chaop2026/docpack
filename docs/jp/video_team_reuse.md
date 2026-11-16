# 영상팀 구조 — 재사용 조사 (2026-11-16)

지시서 0번. **읽기 전용 조사였다.** `~/Projects/naeilalbum` 의 파일은 **한 줄도 바꾸지 않았다.**

⚠️ 확인 방법에 함정이 있어서 적어둔다: `git -C ~/Projects/naeilalbum status` 는 **깨끗하지 않다**
(수정 4건 + untracked 4건). 그것은 **그쪽 세션이 같은 시각에 돌고 있었기 때문**이고 내 것이
아니다 — 근거는 mtime 이다. 이 세션은 **22:38 에 시작**했고 그 파일들은 전부
22:15~22:37(`scripts/promo/render.mjs` 22:37, `thumb.mjs` 22:34, `.gitignore` 22:30)이다.
**「status 가 더럽다」를 「내가 건드렸다」로 읽으면 틀린다** — 그래서 판정 근거를 status 가
아니라 **시각**에 둔다.

## 결론 한 줄

재사용할 **에이전트 정의와 승인 대시보드는 존재하지 않았다.** 대신 내일앨범에는
**영상 파이프라인의 설계 패턴**이 있고(2026-11-16 작성), 그 패턴을 가져왔다.
에이전트 4개는 `~/.claude/agents/` 에 **서비스 중립으로 새로 만들었고**,
서비스 값은 각 저장소의 `config/video_team.yml` 에서 읽는다.

## 조사한 것과 측정값

| 조사 대상 | 실측 | 판정 |
|---|---|---|
| `~/.claude/agents/` | 26개 `.md`. 영상 관련은 **`video-producer.md` 1개** | 부분 재사용 (아래) |
| `~/Projects/naeilalbum/.claude/agents/` | **디렉터리 자체가 없다** (`ls: .claude: No such file or directory`) | 재사용 대상 0건 |
| naeilalbum 승인 대시보드 | `routes.rb` 의 `post :approve` 는 **학급 단위 사진 승인**(교사 화면의 「검수 중」 해제)이다. 영상 승인 화면 **0건** | 재사용 불가 — 다른 도메인 |
| naeilalbum `scripts/promo/` | `render.mjs` · `thumb.mjs` · `translate.mjs` · `lib/ep.mjs` (2026-11-16) | **패턴 재사용** |
| naeilalbum `content/promo/epNN/` | 회차 = 폴더 하나. `master.mp4`(글자 없음) + `overlay_{lang}.json` + `subs/*.srt` + `thumb_{lang}.png` + `provenance.json` | **규약 재사용** |
| docpack 기존 영상 자산 | `content/jp/epNN/shorts.mp4` **8편**(S10, `make_episode.mjs` 안에 있다) | 기반이 이미 있다 |

### `~/.claude/agents/video-producer.md` 를 덮어쓰지 않은 이유

그 파일은 **롤리·헬로코리안 전용**이다 — 첫 줄부터 「마케팅 전략(SSOT)과
`docs/S_videoGen/` 설계를 먼저 읽고」이고, 교사 스토리·썸네일 맨앞 원칙이 박혀 있다.
docpack 에는 그 경로가 없고, 지우면 그쪽 세션이 조용히 깨진다.
⇒ **건드리지 않았다.** 새 4개는 `video-story` · `video-production` · `video-thumbnail` ·
`video-qa` 라는 **다른 이름**을 쓴다(이름 충돌 0건 — `ls ~/.claude/agents/ | grep ^video-` 로 확인).

## naeilalbum 에서 **가져온 것** (패턴 — 파일 복사 아님)

| 패턴 | 어디서 | docpack 에서 어떻게 |
|---|---|---|
| **글자는 master 에 굽지 않는다** | `content/promo/README.md` | ⚠️ **채택하지 않았다** — 사유는 아래 |
| 템플릿 HTML + 치환 + playwright 스크린샷 | `thumb.mjs` | `make_thumbnail.mjs` 가 같은 모양. 단 `SF_THUMB()` 함수 호출식(기존 `shorts_card.html`·`carousel.html` 의 관례)을 따랐다 |
| 사진은 `data:` URI 로 박는다 | `thumb.mjs:37` — file:// 상대경로는 폴더를 옮기면 **조용히 빈 칸**이 된다 | 같은 이유로 같게 했다 |
| 글자 수 제한을 **언어별로** 걸고, 넘으면 **거부**한다 | `thumb.mjs:69-84` (ko 8자 하드, 그 외 경고) | JA 2줄 12자. 넘으면 **경고 + manifest 기록**(거부는 아니다 — 사유 아래) |
| playwright 를 **한 벌만** 깐다 | `thumb.mjs:13` 주석 | docpack 은 이미 `test/safe/node_modules` 를 빌려 쓴다(`make_episode.mjs:470`). 같은 설치본을 쓴다 |
| 종료 코드로 실패 종류를 구별(`EpError(code)`) | `lib/ep.mjs` | `make_thumbnail.mjs`·`make_short.mjs` 가 2=입력 문제, 1=빌드 실패 |
| `provenance.json` 없으면 렌더 거부 | `README.md` | ⚠️ **해당 없음** — SafeFile 영상에는 사람 얼굴이 0장이다(더미 서류와 앱 화면뿐). 없는 위험에 게이트를 달면 다음 사람이 게이트를 무의미하게 읽는다 |

### 「글자를 master 에 굽지 않는다」를 채택하지 않은 이유

내일앨범은 **한 영상을 ko·en·ja 세 언어로 낸다.** 글자를 구우면 번역판마다 영상을 다시
만들어야 하므로 그 규칙이 load-bearing 하다.

SafeFile JP 쇼츠는 **일본어 단일**이다(전략 v3 §2 — 채널 `@safefile_jp`, JA). 그리고
`make_episode.mjs:907-913` 이 **반대 방향의 근거**를 이미 적고 있다: 쇼츠는 **음소거로
자동재생**되고 플랫폼이 soft subtitle 을 신뢰성 있게 렌더하지 않으므로 **픽셀에 없는 글자는
아무도 읽지 않는다.** 두 규칙은 서로 모순이 아니라 **다른 제약을 푼다** — 하나는 번역 비용,
하나는 음소거 가독성. 영어판 쇼츠를 내게 되면 그때 `overlay_*.json` 분리가 필요해지고,
그 조건을 `docs/jp/youtube_longform.md` 백로그에 적어뒀다.

### 글자 수 초과를 「거부」가 아니라 「경고」로 한 이유

내일앨범의 `thumb.mjs` 는 한국어 8자를 넘으면 `exit 3` 으로 **거부한다**. docpack 에서는
경고로 두고 manifest 에 적는다. 근거는 이 저장소의 기존 관례다 —
`make_episode.mjs:1111-1114` 가 쇼츠 제목 20자 초과를 **경고로** 다루고, 같은 파일
:1106-1110 이 그 이유를 적고 있다(「잘린 제목은 저자가 쓰지 않은 제목이므로, 조용히 자르지
않고 보이게 보고한다」). 거부로 바꾸면 **다른 네 개 산출물까지 못 만들고 끝난다** —
이 파이프라인이 「실패는 부분적이다」를 설계로 삼은 바로 그 지점이다(:35-38).
⚠️ 단 **규격(픽셀 크기)은 거부한다.** 글자는 사람이 읽고 고칠 수 있지만 1080×1920 이 아닌
파일은 업로드에서 잘리고, 잘린 뒤에는 안 보인다 — 기존 카루셀 검사와 같은 기준이다.

## 새로 만든 것 (docpack · 공용)

| 위치 | 무엇 | 서비스 중립? |
|---|---|---|
| `~/.claude/agents/video-story.md` | 주제 점검 · hook 3안 · 쇼츠 대본 | ✅ 설정 파일에서 값을 읽는다 |
| `~/.claude/agents/video-production.md` | 쇼츠 · 월 1편 긴 영상 초안 | ✅ |
| `~/.claude/agents/video-thumbnail.md` | 틀 적용 2안 · 월 1회 트렌드 메모 · 틀 버전 | ✅ |
| `~/.claude/agents/video-qa.md` | 산출물만 보는 검사 + Codex 요청문 생성 | ✅ |
| `config/video_team.yml` | docpack 의 서비스 값(service · lang · approver_lang · 가드 · 틀 경로 · 채널 핸들) | — 저장소별 |

**중립성의 판정 기준은 「문장에 SafeFile 이 안 적혔다」가 아니다**: 네 정의 중 어디에도
`slimfile.net`·`@safefile_jp`·`content/jp`·`guard_rules.json` 경로가 **하드코딩되어 있지
않고**, 전부 `config/video_team.yml` 의 키 이름으로만 참조한다. 설정이 없으면
**추측하지 않고 멈춘다**(각 정의의 「입력이 없을 때」 절). 다른 저장소에 같은 네 에이전트를
쓰려면 그 저장소에 `config/video_team.yml` 하나를 두면 된다.

## 남는 관찰

- 내일앨범 `scripts/promo/lib/ep.mjs` 의 `EpError` 는 이 저장소에도 있으면 좋은 물건인데,
  **공용 라이브러리를 만들지 않았다** — 두 저장소가 파일을 공유하면 한쪽 변경이 다른 쪽을
  깨고, 그걸 알려줄 테스트가 양쪽 어디에도 없다. 패턴만 가져왔다.
- naeilalbum `docs/promo/SHORTS_w01_growth.md`(12KB, 2026-11-16)는 **쇼츠 기획서 서식**으로
  읽을 만하지만, 그쪽은 성장 스토리(사람 얼굴)이고 이쪽은 서류 작업이라 구성이 다르다.
  이번 `plan_ko.md` 서식은 그 문서를 베끼지 않고 docpack 의 `summary_ko.md`(S9) 관례를 따랐다 —
  승인자가 이미 매주 읽는 서식이다.
