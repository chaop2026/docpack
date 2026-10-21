# SafeFile JP S6: 랜딩 3페이지 + 파일럿 폼 + 익명 계측 + 접촉 로그. 배포는 하지 말 것.

## 자율 실행 규칙
- 중간 확인 없이 끝까지. 막히면 CLAUDE.md 「JP-1 이슈 로그」에 기록하고 계속. 3-Strike 적용. 시간 약속 금지.
- 기존 골든(test/safe run.mjs, check_matrix, test/sw) 전부 유지. public/safe/index.html 의 탐지 로직은 건드리지 말 것(이번 범위 밖).
- 완료 시 커밋(푸시·배포 금지). 마지막 줄 "S6_DONE".

## 읽을 것
docs/jp/jp_landing_copy_2026-10-22.md (문안 정본 — 문구를 바꾸지 말 것, 레이아웃만), docs/jp/jp_forecast_report_2026-10-22.md §8 (계측 요구), public/safe/index.html 의 디자인 토큰·폰트(IBM Plex Sans KR)·헤더 구조, config/routes.rb, app/controllers/api/safe_scan_controller.rb (API 컨트롤러 패턴)

## A. 랜딩 3페이지 (정적 HTML, public/safe/jp/)
1. `public/safe/jp/nyusatsu/index.html`, `public/safe/jp/honnin-kakunin/index.html`, `public/safe/jp/ai-mae/index.html`. 문안은 정본 그대로(JA 본문). EN은 각 페이지 하단 접이식 섹션 또는 `?lang=en` 토글(간단한 쪽 선택).
2. 디자인: /safe/ 와 같은 토큰·폰트·헤더(SafeFile │ SlimFile). 모바일 우선, 16px 측면 여백. 광고 스크립트·제3자 트래커 금지(계측은 자체 엔드포인트만).
3. 각 페이지 CTA 버튼은 `/safe/?lang=ja&purpose=<identity_submit|bid_attachment|consult_share>&from=<nyusatsu|honnin|aimae>` 로 연결. index.html 이 `purpose` 쿼리를 읽어 업로드 직후 제출목적을 미리 선택하도록 **최소 변경**(탐지 로직 아님, URL 파라미터 → jpSetPurpose 호출만). `from` 은 계측에만 사용.
4. SEO: title/meta description 정본대로, `<html lang="ja">`, canonical, OG 이미지는 /safe/ 의 기존 이미지 재사용, JSON-LD(SoftwareApplication, FAQPage는 nyusatsu 만). sitemap.xml 에 3개 URL 추가. robots 허용.
5. 페이지 1 의 「パイロットに申し込む」 폼: 회사명·업종(select: 建設業/電子入札代行/行政書士/その他)·월간 제출 건수(select)·자주 쓰는 발주처(텍스트)·연락처 메일. 개인정보 입력 최소. 동의 문구 1줄(「ご連絡のためにのみ使用します」).

## B. 파일럿 폼 백엔드
6. `POST /api/jp_pilot` → `Api::JpPilotController#create`: 서버 측 검증(메일 형식, 길이), 테이블 `jp_pilot_requests`(company, industry, monthly_count, authority, email, from, created_at) 마이그레이션, 저장 후 기존 메일러 패턴으로 Justin 에게 알림 메일(제목 「[SafeFile JP] パイロット申込」). 스팸 가드: honeypot 필드 + 같은 IP 10분 3회 제한. 성공 시 페이지 내 감사 메시지(JA).
7. 관리: `admin` 네임스페이스에 목록 페이지 1개(기존 admin 패턴 따름). 없으면 rails console 조회 안내만 README 에.

## C. 익명 계측 (개인정보 0)
8. `POST /api/safe_events` → `Api::SafeEventsController#create`: 허용 이벤트 `upload|doc_class|purpose|download|landing_view|cta_click` 와 허용 값만 화이트리스트(doc_class: shikaku_kakuninsho|unten_menkyo|mynumber_card|juminhyo|unclassified|none, purpose: 4종, format: jpg|png|pdf, locale: ko|en|ja|es, from: nyusatsu|honnin|aimae|direct, ext: pdf|jpg|png|docx|other, pages: 1|2|3-5|6+). 그 외 키·텍스트·좌표·파일명·IP 저장 금지(IP 는 해시도 저장하지 않음). 테이블 `safe_events`(name, props jsonb, created_at).
9. index.html 에서 `navigator.sendBeacon` 으로 위 6개 시점에 전송(실패해도 UI 무영향). 처리 화면에 제3자 스크립트 없음 유지. 쿠키 사용 안 함.
10. 집계 rake `safe:jp_weekly` : 지난 7일 이벤트를 doc_class·purpose·from 별 카운트로 docs/jp/metrics/YYYY-WW.md 에 기록(예측 P6·P10·P11 검증용).

## D. 접촉 로그·운영 파일
11. `docs/jp/outreach_log.md` 생성: 표 헤더 `| 날짜 | 업체 유형 | 발주처 | 회신 | 파일럿 | 결제 | 메모 |` + 예시 행 0건. `docs/jp/metrics/` 폴더 생성.
12. `docs/jp/s6_report.md`: 생성 파일 목록, 라우트, 마이그레이션, 로컬 확인 방법(`bin/rails s` 후 3 URL 과 폼 POST curl 예시), 미완 항목. 골든 통과 로그 첨부.

## E. 테스트
13. 컨트롤러 테스트 2개(허용 외 이벤트 거부, 파일럿 폼 honeypot 거부). `node test/safe/run.mjs` 전체 통과 재확인(index.html 최소 변경이 골든을 깨지 않는지).
