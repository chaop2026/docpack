# SafeFile JP 콘텐츠 파이프라인

## 사용법 (3줄)

1. `content/jp/topics.json` 에서 다음 회차를 고른다 (`ep` = 발행 순서 = `week`).
2. `content/jp/epNN/post_ja.md` 를 쓴다 — frontmatter(`title` · `hook` · `bullets` 3개 ·
   `cta` · 트랙 A 는 `captions` 3줄) + 본문 600~900자. 영어판 `post_en.md` 도 손으로 쓴다.
3. `node scripts/content/make_episode.mjs NN` → 같은 폴더에 X 스레드 · 캐러셀 3장 ·
   (트랙 A) 데모 GIF/MP4 · `manifest.json` 이 생긴다.

```
node scripts/content/make_episode.mjs 1            # 전부
node scripts/content/make_episode.mjs 1 --no-demo  # GIF 건너뛰기(빠름)
```

## 게시 절차

1. `manifest.json` 의 `warnings` 를 먼저 읽는다. 140자 초과 트윗·캐러셀 글자 넘침은
   **자동으로 줄이지 않는다** — 줄이면 아무도 쓰지 않은 문장이 나간다. `post_ja.md` 를 고쳐
   다시 돌린다.
2. X · YouTube Shorts · Instagram · 블로그에 올린다.
3. 올린 채널을 `manifest.json` 의 `posted` 에서 `true` 로 바꾼다.
4. `content/jp/topics.json` 의 해당 회차 `status` 를 `posted` 로 바꾼다.

`posted` 가 전부 `false` 로 시작하는 것은 의도다 — 기본값이 「완료」인 체크리스트는
체크리스트가 아니다.

## 필요한 것

- **node** · **ffmpeg**(GIF·MP4) · **playwright + chrome 채널**.
  playwright 는 골든 하네스의 설치본을 빌려 쓴다(버전이 갈라지지 않게 사본을 만들지 않는다):

  ```
  cd test/safe && npm i && npx playwright install chrome
  ```

  없으면 스크립트가 이 명령을 그대로 출력하고 멈춘다.

## 이 스크립트가 **하지 않는** 것

- **`post_en.md` 를 생성하지 않는다.** 마케팅 문안의 기계 번역은 기계 번역처럼 읽히고,
  이 프로젝트의 영어판은 번역이 아니라 **병행 재작성**이다(랜딩 3페이지와 같은 원칙).
  파일이 없으면 경고만 남긴다.
- **본문을 고치지 않는다.** 금지 규칙 위반은 **보고하고 중단**한다 — 정규식을 만족시키려고
  남의 문장을 고쳐 쓰면 아무도 고르지 않은 카피가 된다.
- **프로덕션을 호출하지 않는다.** 데모는 `public/` 을 서빙하는 로컬 서버에서 녹화한다.

## 금지 규칙 (스크립트가 강제한다)

`make_episode.mjs` 는 frontmatter + 본문 전체를 검사하고, 하나라도 걸리면 **아무 파일도 쓰지
않고** exit 1 한다:

| 규칙 | 이유 |
|---|---|
| 사건명(`タイムズカー`) 불사용 | 전략 v2 / 시장결정 v2 |
| `絶対` · `唯一` · `必ず安全` · `防ぎます/防げます` 불사용 | 「原則 / リスクを下げる / 確認する」로 쓴다 |
| `一括処理` · `一括ダウンロード` 불사용 | **아직 출시되지 않았다.** 미구현 기능 홍보 금지 |
| 본문에 `提出先の指示を必ず確認してください` 포함 | 모든 How-to 필수 |

`topics.json` 에 `blocked_until` 이 있는 회차(ep32 = 일괄처리)는 **빌드 자체를 거부한다.**
기능이 나오기 전에 쓰지 않게 하려는 것이고, 목록에서 지우지 않는 이유는 슬롯이 잊히지 않게
하기 위해서다.

## 산출물

| 파일 | 내용 |
|---|---|
| `x_thread.md` | 5트윗(훅+제목 / 불릿 ×3 / CTA+UTM URL). 각 트윗에 **글자 수**가 붙고 140자 초과는 `⚠ OVER` 로 표시된다 |
| `carousel_1..3.png` | 1080×1350. 1=제목+훅, 2=불릿, 3=CTA+URL. 넘치면 2%씩 축소하고 52% 바닥에서도 넘치면 경고 |
| `demo.gif` / `demo.mp4` | **트랙 A + 더미가 있는 문서**만. 720px 폭, 0.5초 간격 최대 40프레임, 하단 자막 3줄 |
| `manifest.json` | 파일·크기 · `demo` 상태 · `warnings` · 게시 체크리스트 |

### 데모를 못 만드는 경우 (전부 정상 동작)

| 상황 | manifest `demo` |
|---|---|
| 트랙 B | `skipped: track B has no tool demo` |
| `--no-demo` | `skipped: --no-demo` |
| 더미가 없는 문서(`契約書`·`給与明細` 등) | `failed: no dummy document exists for doc="…"` |
| 녹화 중 실패 | `failed: <이유>` — 나머지 산출물은 전부 만들어진다 |

더미가 있는 문서는 네 가지뿐이다: `shikaku_kakuninsho` · `unten_menkyo` · `mynumber_card` ·
`juminhyo`(= 골든 픽스처가 있는 알파 4종). `topics.json` 의 `doc` 이 그 네 키 중 하나면 데모를
녹화하고, 그 외(일본어 라벨)면 **없다고 말한다**. 없는 것을 그럴듯하게 만들지 않는다.

### 데모 프레임이 「0.5초 간격」이지만 연속 20초가 아닌 이유

촬영풍 JPG 는 Tesseract OCR 에 수십 초가 걸린다. 40프레임을 한 번에 연속으로 찍으면
**전부 진행 바**가 되고 완성된 GIF 에 문서가 한 장도 안 나온다. 그래서 단계별로 나눠 찍는다
(업로드 4 → 탐지 결과 10 → 목적 바 6 → 결과 나머지). 간격 0.5초·상한 40프레임은 그대로다.

## 검수 포인트

- 캐러셀 3장: 글자 잘림(`warnings` 에 `overflows` 가 있으면 반드시 본문을 줄인다), 하단
  「提出先の指示を必ず確認してください。」가 보이는지, URL 줄바꿈이 읽히는지.
- GIF: 자막 3줄이 아래 바 안에 들어가는지, **띠 아래 원문이 비치지 않는지**(비치면 캡처가
  아니라 제품 문제다), 마지막 프레임이 결과 화면인지.
- `x_thread.md`: `⚠ OVER` 가 하나라도 있으면 그대로 올리지 않는다.
