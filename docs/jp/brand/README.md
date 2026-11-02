# SafeFile JP 브랜드 자산 (2026-10-24 확정)

## 확정 로고: B 개선판 — "S" 모노그램
- 먹색(#1A1613) 정사각 배경 위에 크림색(#F6F4EE) 굵은 S. S의 꼬리 끝 한 토막을 떼어내 "검은 띠로 가린다"는 뜻을 암시.
- 선택 이유: X 타임라인(48px 원형)에서도 또렷이 읽히는 유일한 안. 노란색(#FFD84D)은 로고에서 제외, 앱 강조색으로만 유지.
- 후보 4안(A 문서+띠 / B S모노그램 / C 「黒塗」문자 / D 방패)과 비교 시트는 `docs/jp/brand/options/` 에 보관.

## 파일 위치 (Mac: ~/Projects/docpack)
| 용도 | 경로 |
|---|---|
| 마스터 벡터 | `public/safe/brand/icon.svg` |
| 파비콘 | `public/safe/brand/favicon.ico` (16/32/48 포함) |
| PNG 아이콘 | `public/safe/brand/icon-{16,32,48,180,192,512}.png` |
| X 프로필 사진 | `public/safe/brand/x_profile_400.png` (400×400) |
| X 헤더 | `public/safe/brand/x_header_1500x500.png` (먹색 배경, 「提出先のルールどおりに、自動で正しく■■■」) |
| 후보 4안·비교 시트·생성 스크립트 | `docs/jp/brand/options/` (`contact_sheet_ABCD.png`, `preview_B2_chosen.png`, `logo_*.svg/png`, `make_options.py`, `make_B2.py`) |

※ 기존 `/safe/` 사이트 파비콘(`public/safe/icon-512.png`, `icon.svg`)은 아직 교체하지 않음. 교체 여부는 별도 결정(교체 시 `public/safe/brand/` 파일을 복사하면 됨).

## 색상 토큰
- INK `#1A1613` · CREAM `#F6F4EE` · SAND `#E8E3D8` · YELLOW `#FFD84D` (/safe/ 디자인 토큰과 동일)
- 폰트: Noto Sans CJK JP (헤더·카루셀), IBM Plex Sans KR (사이트)

## X 계정 @safefile_jp 프로필 값
- 표시 이름: `SafeFile セーフファイル`
- 소개: 提出書類の個人情報だけを、提出先のルールどおりに自動で黒塗り。ファイルはブラウザの外に出ません。資格確認書・免許証・住民票に対応。無料・登録不要。入札添付の事業者向けチームプランは先行利用の事務所を募集中（無料）。
- 웹사이트: https://slimfile.net/safe/jp/nyusatsu/
- 위치: Japan

## 재생성 방법
```
cd ~/Projects/docpack/docs/jp/brand/options
python3 make_B2.py      # logo_B2.svg/png, header_B2.png, preview_B2.png
```
(Playwright + Noto Sans CJK 필요. 벡터 원본은 `logo_B2_chosen.svg`이므로 보통 재생성 불필요.)

## 첫 고정 트윗 (2026-10-24 게시·고정 완료)
- URL: https://x.com/safefile_jp/status/2113999418223685682
- 미디어: `content/jp/ep01/demo.gif`
- 본문:
  入札添付の資格確認書、番号だけを自動で黒塗り。
  書類の種類を判定し、提出先のルールどおりの箇所だけを隠します。ファイルはブラウザの外に出ません。
  無料・登録不要 → https://slimfile.net/safe/jp/nyusatsu/?utm_source=x&utm_campaign=pin
  提出先の指示を必ず確認してください。
