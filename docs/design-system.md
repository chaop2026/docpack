# Bento Soft Grid Design System

DocPack의 전체 UI에 적용되는 디자인 시스템.

---

## Color Tokens

### Base

| Token | Value | Usage |
|-------|-------|-------|
| Page background | `#F8F7F4` | body, admin background |
| Card background | `#ffffff` | cards, modals, inputs, tables |
| Card border | `0.5px solid #E5E3DC` | cards, tables, inputs, banners |
| Primary text | `#1A1918` | headings, labels, card titles |
| Secondary text | `#6B6963` | descriptions, hints, timestamps |
| Status success | `#16a34a` | done status, reduction % |
| Status danger | `#dc2626` | failed status, error messages |

### Service Colors

각 서비스는 3가지 컬러 세트를 가짐: Primary (버튼, 강조), Light (배경, 아이콘 박스), Text (태그 텍스트).

| Service | Primary | Light | Text |
|---------|---------|-------|------|
| Image Compress (Teal) | `#0A6E8A` | `#E1F5F9` | `#07596F` |
| PDF Conversion (Amber) | `#F59E0B` | `#FEF3C7` | `#92400E` |
| SNS Resize (Purple) | `#7C3AED` | `#EDE9FE` | `#4C1D95` |

### 적용 규칙

- **버튼**: 서비스 Primary 배경 + 흰색 텍스트
- **아이콘 박스**: 서비스 Light 배경 + 서비스 Primary 아이콘
- **태그(chip)**: 서비스 Light 배경 + 서비스 Text 컬러
- **업로드 존 hover**: 서비스 Primary dashed border + 서비스 Light 배경
- **프로그레스 바 / 스피너**: 서비스 Primary 컬러

---

## Typography

| Element | Size | Weight | Extra |
|---------|------|--------|-------|
| Page title (h1) | 22px | 600 | `letter-spacing: -0.02em` |
| Hero title | 28px | 700 | `letter-spacing: -0.03em` |
| Card title | 15px | 600 | `letter-spacing: -0.01em` |
| Banner title | 14px | 600 | `letter-spacing: -0.01em` |
| Body / description | 13px | 400 | `color: #6B6963`, `line-height: 1.55` |
| Tag (chip) | 10px | 600 | `uppercase`, `letter-spacing: 0.04em` |
| Button text | 13px | 600 | - |
| Admin table header | 10px | 600 | `uppercase`, `letter-spacing: 0.04em` |

### Font Stack

```css
font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
-webkit-font-smoothing: antialiased;
```

---

## Border Radius

| Element | Radius | CSS Variable |
|---------|--------|-------------|
| Page card | 20px | `--r-card` |
| Button | 12px | `--r-btn` |
| Icon box | 14px | `--r-icon` |
| Tag / chip | 20px | `--r-chip` |
| Banner | 14px | `--r-banner` |

---

## Spacing

| Context | Value |
|---------|-------|
| Container max-width | 860px |
| Container padding | 2rem 1.5rem |
| Card padding | 1.5rem |
| Banner padding | 1rem 1.25rem |
| Feature card gap | 1rem |
| Banner section gap | 0.625rem |

---

## Transitions & Hover

| Element | Effect | Duration |
|---------|--------|----------|
| Feature card hover | `translateY(-3px)` + `box-shadow: 0 8px 24px rgba(0,0,0,0.06)` | 0.2s |
| Banner hover | `translateX(3px)` + `box-shadow: 0 4px 16px rgba(0,0,0,0.06)` | 0.15s |
| Button hover | `opacity: 0.88` | 0.15s |
| Back button hover | `translateX(-2px)` | 0.2s |
| Upload zone hover | border-color + background 변경 | 0.2s |

---

## Components

### Feature Card (Home)

```
+---------------------------+
| [Icon Box]                |
| [TAG]                     |
| Card Title                |
| Description text...       |
| [CTA Button]              |
+---------------------------+
```

- 3-column grid (`repeat(3, 1fr)`)
- `flex-direction: column`, `align-items: flex-start`
- 모바일: 1-column

### Banner Card

```
+------------------------------------------+
| [Icon] | Title            | [CTA Button] |
|        | Description      |              |
+------------------------------------------+
```

- 흰 배경 + `#E5E3DC` 테두리
- 컬러 순환: teal -> gold -> purple (인덱스 % 3)
- 모바일: column 방향, 중앙 정렬

### Upload Zone

- 2px dashed `#E5E3DC` border
- 20px border-radius
- hover: 서비스별 Primary border + Light 배경

### Result Card

- 흰 배경, `#E5E3DC` 테두리, 20px radius
- size comparison: flex row, 13px font
- download button: 서비스 Primary 컬러

### Toast Notification

- 고정 위치: top-right
- 흰 배경 + `#E5E3DC` 테두리
- 14px border-radius
- success: green left border / error: red left border
- 슬라이드 인/아웃 애니메이션

---

## Admin Panel

- 사이드바: `#1A1918` 배경, 로고 accent `#0A6E8A`
- 메인 영역: `#F8F7F4` 배경
- 테이블: 흰 배경, `#E5E3DC` 테두리, 20px radius
- 행 교차: 짝수 행 `#FDFCFA`, hover `#F8F7F4`
- 인풋: 12px radius, focus시 `#0A6E8A` border + 3px glow
- 버튼: primary `#0A6E8A`, 12px radius
- 로그인 카드: 흰 배경, 20px radius, 가운데 정렬

---

## CSS Custom Properties (Variables)

```css
:root {
  --bg: #F8F7F4;
  --card-bg: #ffffff;
  --card-border: 0.5px solid #E5E3DC;
  --border-color: #E5E3DC;
  --text: #1A1918;
  --text-sub: #6B6963;
  --success: #16a34a;
  --danger: #dc2626;

  --compress: #0A6E8A;
  --compress-light: #E1F5F9;
  --compress-text: #07596F;

  --pdf: #F59E0B;
  --pdf-light: #FEF3C7;
  --pdf-text: #92400E;

  --social: #7C3AED;
  --social-light: #EDE9FE;
  --social-text: #4C1D95;

  --r-card: 20px;
  --r-btn: 12px;
  --r-icon: 14px;
  --r-chip: 20px;
  --r-banner: 14px;
}
```

---

## File Locations

| File | Purpose |
|------|---------|
| `app/assets/stylesheets/application.css` | 메인 스타일시트 (모든 Bento 토큰) |
| `app/views/layouts/application.html.erb` | 프론트 레이아웃 (top-bar) |
| `app/views/layouts/admin.html.erb` | 어드민 레이아웃 (inline Bento styles) |
| `app/views/shared/_banners.html.erb` | 배너 컴포넌트 |
| `app/views/pages/home.html.erb` | 홈 Bento grid 카드 |
