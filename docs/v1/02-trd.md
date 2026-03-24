# DocPack v1 — Technical Requirements Document

## 1. 기술 스택

| 레이어 | 기술 |
|--------|------|
| 프레임워크 | Rails 8.0 |
| 프론트엔드 | Hotwire (Turbo + Stimulus) |
| DB | PostgreSQL 16 |
| 이미지 처리 | image_processing gem + libvips |
| PDF 생성 | combine_pdf gem |
| 파일 관리 | ActiveStorage (로컬 → 추후 S3) |
| 배포 | Fly.io |
| 광고 | Google AdSense |
| PWA | serviceworker-rails |

---

## 2. Gem 목록

```ruby
# Gemfile 추가 목록

# 이미지 처리
gem "image_processing", "~> 1.2"

# PDF 생성
gem "combine_pdf"

# 환경변수
gem "dotenv-rails", groups: [:development, :test]

# 파일 업로드
# ActiveStorage 기본 사용 (rails 내장)
```

---

## 3. DB 설계

### conversions (변환 작업)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | bigint | PK |
| conversion_type | string | 'pdf' / 'compress' / 'social' |
| status | string | 'pending' / 'done' / 'failed' |
| original_size | integer | 원본 총 용량 (bytes) |
| result_size | integer | 결과 용량 (bytes) |
| expires_at | datetime | 파일 만료 시각 (1시간) |
| created_at | datetime | |

### (파일은 ActiveStorage로 연결, DB 컬럼 불필요)

---

## 4. 라우트 설계

```ruby
# config/routes.rb

Rails.application.routes.draw do
  root "pages#home"

  resources :conversions, only: [:create, :show] do
    member do
      get :download
    end
  end

  get "/compress", to: "pages#compress"
  get "/pdf",      to: "pages#pdf"
  get "/social",   to: "pages#social"
  get "/about",    to: "pages#about"
end
```

---

## 5. 핵심 처리 로직

### 이미지 압축
```ruby
# app/services/image_compressor.rb
# libvips로 품질 조절하며 2MB 이하 달성
# 1차: quality 80 → 2MB 이하면 완료
# 2차: quality 60 → 아직 크면
# 3차: 해상도 50% 축소 + quality 60
```

### PDF 변환
```ruby
# app/services/pdf_builder.rb
# 1. 각 이미지를 압축 (A4 기준 선명도 유지, ~200KB/장)
# 2. combine_pdf로 순서대로 합치기
# 3. 전체 2MB 이하 확인, 초과 시 품질 재조정
```

---

## 6. 파일 보안

- ActiveStorage 파일: 변환 완료 후 **1시간 뒤 자동 삭제**
- Cron job (solid_queue): `CleanupExpiredFilesJob` 매 30분 실행
- 사용자 식별 없이 처리 (비로그인)

---

## 7. 포트 및 환경 설정

```bash
# .env (개발)
PORT=3001
DB_HOST=localhost
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

```ruby
# config/puma.rb
port ENV.fetch("PORT") { 3001 }
```

---

## 8. 배포 계획

```
개발: localhost:3001
스테이징: fly.io (docpack-staging)
프로덕션: fly.io (docpack) + docpack.kr 도메인
```

---

## 9. PWA 설정

- `manifest.json`: 앱 이름, 아이콘, 테마 컬러
- `service_worker.js`: 오프라인 캐시 (결과 페이지)
- iOS: "홈 화면에 추가" 안내 배너
- Android: 자동 설치 프롬프트
