# DocPack v1 — Tasks & Implementation Plan

## Phase 1: 기반 설정 (Day 1)

- [ ] `docs/v1/` 폴더 구조 생성
- [ ] Gemfile에 image_processing, combine_pdf, dotenv-rails 추가
- [ ] `bundle install`
- [ ] `.env` 파일 생성 (PORT=3001)
- [ ] `config/puma.rb` 포트 3001 고정
- [ ] `rails db:migrate`
- [ ] Git 초기 커밋

## Phase 2: DB + 모델 (Day 1)

- [ ] `Conversion` 모델 생성
  - conversion_type, status, original_size, result_size, expires_at
- [ ] ActiveStorage 설치 (`rails active_storage:install`)
- [ ] Conversion에 has_many_attached :source_files
- [ ] Conversion에 has_one_attached :result_file
- [ ] `rails db:migrate`

## Phase 3: 서비스 레이어 (Day 2)

- [ ] `app/services/image_compressor.rb`
  - 단계별 품질 조절 (80 → 60 → 해상도 축소)
  - 목표: 2MB 이하
- [ ] `app/services/pdf_builder.rb`
  - 이미지 압축 후 combine_pdf로 합치기
  - 전체 2MB 이하 검증
- [ ] `app/services/social_resizer.rb`
  - 프리셋별 크롭 + 리사이즈
  - 인스타/페이스북 4가지 프리셋

## Phase 4: 컨트롤러 + 라우트 (Day 2)

- [ ] `PagesController` (home, compress, pdf, social, about)
- [ ] `ConversionsController` (create, show, download)
- [ ] Turbo Stream으로 비동기 처리 결과 표시
- [ ] 라우트 설정

## Phase 5: UI (Day 3)

- [ ] 메인 페이지: 드래그앤드롭 업로드 존
- [ ] 변환 방식 탭 선택 UI
- [ ] 진행 상태 표시 (Turbo Frame)
- [ ] 결과 페이지: 용량 비교 + 다운로드 버튼
- [ ] 소셜 프리셋 선택 UI
- [ ] 모바일 반응형

## Phase 6: AdSense + PWA (Day 4)

- [ ] Google AdSense 코드 삽입 (상단 배너, 결과 하단)
- [ ] `manifest.json` 생성
- [ ] Service Worker 등록
- [ ] iOS 홈 화면 추가 안내 배너

## Phase 7: 파일 정리 + 보안 (Day 4)

- [ ] `CleanupExpiredFilesJob` (Solid Queue)
  - 1시간 지난 파일 자동 삭제
- [ ] 최대 업로드 제한 (50장, 단일 20MB)
- [ ] 에러 핸들링 (용량 초과, 지원 안 되는 형식)

## Phase 8: 배포 (Day 5)

- [ ] Fly.io 앱 생성 (`fly launch`)
- [ ] 환경변수 설정 (`fly secrets set`)
- [ ] 도메인 연결 (docpack.kr)
- [ ] SSL 자동 설정 확인
- [ ] TeacherMatch에 DocPack 링크 추가

---

## 커밋 컨벤션

```
feat: 새 기능
fix: 버그 수정
docs: 문서
style: UI 변경
refactor: 리팩토링
deploy: 배포 관련
```

---

## 브랜치 전략

```
main
└── feature/image-compression
└── feature/pdf-builder
└── feature/social-presets
└── feature/adsense-pwa
```
