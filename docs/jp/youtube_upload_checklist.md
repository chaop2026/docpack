# YouTube 업로드 체크리스트 (@safefile_jp)

**2026-11-16.** 올리는 사람이 화면을 보면서 따라가는 목록. 에이전트는 업로드하지 않는다
(`config/video_team.yml` 의 `forbidden`).

---

## 0. 올리기 전에 — 매번

- [ ] **Studio 왼쪽 위 채널명이 `SafeFile セーフファイル` 인가.**
      🔴 개인 기본 채널(`Sunghoon Sim`)에 올리면 **되돌릴 수 없다** — 비공개로 바꿔도
      공개 URL 이 이미 나간 뒤다. 채널 전환은 프로필 아이콘 → 「채널 전환」.
- [ ] 그 회차의 `content/jp/epNN/manifest.json` 과 `short_ja.json` 의
      **`posted` 가 아직 false** 인가 (이미 올린 회차를 다시 올리면 URL 이 두 개가 된다)
- [ ] Gate 2 (토요일) 승인이 끝났는가 → `/admin/jp/packages`

---

## 1. 쇼츠

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac 일반 터미널 ·
> 올릴 파일과 문구 확인

```
cat content/jp/ep01/shorts_title_ja.txt content/jp/ep01/shorts_desc_ja.txt
```

### 1-1. 파일

- [ ] `content/jp/epNN/shorts.mp4` — **1080×1920 · 30초 이내**
      (`short_ja.json` 의 `duration_sec`·`size` 가 ffprobe 실측값이다)
- [ ] `short_ja.json` 의 `warnings` 가 비어 있는가. 남아 있으면 **읽고 판단**한다

### 1-2. 제목·설명

- [ ] 제목 = `shorts_title_ja.txt` 그대로 (20자 + 해시태그 3개)
- [ ] 설명 = `shorts_desc_ja.txt` 그대로
- [ ] 🔴 **설명란의 URL 은 눌리지 않는다.** 그대로 두되, **거기에 전환을 기대하지 않는다**

### 1-3. 썸네일

⚠️ **먼저 1분만 확인한다 (한 번만, 결과를 적어 둘 것).**
업로드 화면의 「썸네일」에 **업로드 버튼이 있는가?**

- **있다** → `thumb_short_a.png`(또는 b)를 **그대로 올린다.** 그리고
  `config/video_team.yml` 의 `shorts_custom_thumbnail` 을 `true`,
  `shorts_custom_thumbnail_verified` 를 `true` 로 고친다
- **없다** → 아래 「프레임 선택」으로 간다

🔴 2026-11-16 시점에 **이 채널에서 확인된 적이 없다.** 지시서는 「YPP 채널부터」라고
했고 같은 날 교차검증은 「인증 계정이면 데스크톱 Studio 에서 가능」이라고 반박했다.
**규칙을 추론하지 말고 우리 화면을 본다.**
어느 쪽이든 쇼츠 피드에는 썸네일이 **보이지 않는다** — 첫 2초가 그 역할을 하고,
끝 화면은 썸네일이 아니라 **CTA** 이므로 그대로 둔다.

### 프레임 선택 (업로드 버튼이 없을 때)

- [ ] 업로드 화면 → 「썸네일」 → **프레임 선택**
- [ ] **스크러버를 끝까지 오른쪽으로 민다.** 거기가 끝 화면이다
      (`short_ja.json` 의 `thumbnail_frame_sec` / `thumbnail_frame_window`.
      ep01 은 `29.5s`, 창은 `29.5–30.0s`)
- [ ] 고른 프레임이 **표지 + 「プロフィールのリンクから」** 인지 눈으로 확인

### 1-4. 고정 댓글

- [ ] `content/jp/channel/pinned_comment_ja.md` 의 본문을 복사
- [ ] `{{NN}}` `{{TITLE}}` 치환 (`{{` 가 남아 있지 않은지 본다)
- [ ] 🔴 **URL 을 넣지 않는다** — 쇼츠 댓글의 링크는 눌리지 않는다
- [ ] 댓글을 **고정**한다 (붙이기만 하면 위로 안 올라간다)

### 1-5. 「관련 동영상」 — 그 달의 긴 영상

- [ ] Studio → 그 쇼츠 → 「관련 동영상」 → 그 달의 긴 영상 선택
- [ ] ⚠️ **고급 기능(전화 인증)이 켜져 있어야 보인다.** 안 보이면 이 항목은 **건너뛰고**
      「허브에 요청」으로 남긴다. 인증은 허브 몫이다
- [ ] 아직 그 달 긴 영상이 없으면 — 올린 뒤에 **돌아와서** 건다

### 1-6. 올린 뒤

- [ ] `content/jp/epNN/short_ja.json` 의 `posted` 에 URL·일시 기록
- [ ] `content/jp/epNN/manifest.json` 의 `posted.youtube_shorts` → `true`,
      `posted.youtube_url` 기록
- [ ] `content/jp/topics.json` 의 `status` 를 `posted` 로 (사람이 직접)

---

## 2. 긴 영상 (월 1편)

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac 일반 터미널 ·
> 그 달 초안 만들기

```
node scripts/content/make_longform.mjs 2026-11
```

- [ ] 본편 편집 완료 (이 스크립트는 **렌더하지 않는다**)
- [ ] 🔴 **목차 초를 실제 영상에 맞춰 고쳤는가.** `script_ja.md` 의 숫자는 **계획값**이다.
      어긋난 목차는 누른 사람을 다른 곳으로 보낸다
- [ ] 썸네일 = `content/jp/epNN/thumb_long_{a,b,c}.png` 중 Gate 1 에서 고른 것
      (긴 영상은 **맞춤 썸네일 업로드가 된다**)
- [ ] 설명 = `content/jp/longform/YYYY-MM/description_ja.txt` 그대로
- [ ] **1행 = 아픔, 2행 = 랜딩 링크.** 3행째부터 접힌다
- [ ] 링크의 `via` 가 **`yt_long`** 인가 (`youtube` 아님)
- [ ] `{{` 가 하나도 남아 있지 않은가
- [ ] 올린 뒤 `content/jp/longform/YYYY-MM/manifest.json` 의 `posted` 기록
- [ ] 그 달 쇼츠 전부에 **「관련 동영상」으로 이 영상을 건다**(1-5)

---

## 3. 채널 설정 — 처음 한 번만

- [ ] 설명: `content/jp/channel/channel_about_ja.md`
- [ ] **프로필 링크 1번 = 랜딩**: `content/jp/channel/profile_links.md`
      🔴 쇼츠 끝 화면이 가리키는 곳이다. 1번이 아니면 끝 화면이 거짓말을 한다
- [ ] 프로필 사진·배너: `content/jp/channel/channel_assets.md`
      (배너는 **중앙 1235×338** 안에만 글자)

### 설정 후 1회 확인

- [ ] 시크릿 창에서 프로필 링크 1번 → **200, 입찰 랜딩**
- [ ] `rake safe:jp_weekly` → `via` 열에 `youtube` 가 늘었는가
      ⚠️ **배포 전에는 늘지 않는다.** 빈 표는 「유입 0」이 아니라
      **「이 차원을 보내는 버전이 아직 배포되지 않았다」**일 수 있다

---

## 4. 이미 올린 회차를 다시 만들었을 때

🔴 **ep01 이 지금 이 상태다.** 2026-11-01 에 게시됐고
(`manifest.json` 의 `posted.youtube_url`), 2026-11-16 에 끝 화면을 넣어 다시 만들었다.

- 올려 둔 영상을 **교체할 수 없다.** YouTube 는 영상 파일 교체를 지원하지 않는다
- 새로 올리면 **새 URL** 이 생기고 **재생수·댓글은 따라오지 않는다**
- 옛 것을 지우면 밖에 나간 링크가 전부 죽는다

→ 선택지는 셋. **사람이 정한다.**

| | 하는 일 | 잃는 것 |
|---|---|---|
| (a) 그대로 둔다 | 다음 회차부터 끝 화면 적용 | ep01 에는 끝 화면이 없다 |
| (b) 새로 올리고 옛 것은 비공개 | ep01 도 끝 화면을 갖는다 | 재생수·댓글·기존 링크 |
| (c) 새로 올리고 둘 다 공개 | 같음 | 같은 내용이 두 개 (권장하지 않음) |

어느 쪽이든 `short_ja.json` 의 `posted` 를 **사실대로** 고친다.
