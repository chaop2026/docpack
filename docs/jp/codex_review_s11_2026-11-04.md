# 교차검증 — S11(7618bc9) + S11b(971a43e) · 2026-11-04

- 검토자: ChatGPT(웹, 추론 Medium) · 입력 docs/jp/private/codex_input_s11.md (diff d43cd76..971a43e, test/·docs/ 제외 + s11_report §12~13)
- 종합: **NO (RED 1건)** → S11c 후 배포
- Claude 자체 확인: RED 근거를 리포에서 재현함(아래 ✔)

| # | 항목 | 판정 | 요지 |
|---|---|---|---|
| 1 | 구조화 데이터 | AMBER | 영어 본문 JP 글의 BreadcrumbList 가 /en/blog(다른 간행물)를 상위로 가리킴. publisher=SafeFile 인데 author·og:site_name=SlimFile 혼재 |
| 2 | hreflang/사이트맵 | GREEN | /ja/blog 를 다른 목록의 alternate 에서 분리한 것이 컨트롤러·사이트맵 일치 |
| 3 | IndexNow | AMBER | IndexNow.key 가 존재만 검사 — 라우트 정규식(/[A-Za-z0-9][A-Za-z0-9_-]{7,127}/)과 형식 불일치 시 제출은 되고 키 파일은 404. 배포 후 /<key>.txt 200 확인 필요 |
| 4 | GA4/AdSense | GREEN | GA4 는 JP 랜딩 3곳만, /safe/ AdSense 제거 확인 |
| 5 | 개인정보 약속 | **RED** | privacy 3-1 의 「/safe/ 에서는 접속 분석도, **제3자 스크립트도** 사용하지 않습니다」(KO 97행·JA 96행) ↔ /safe/ 가 cdnjs 에서 pdf.js·pdf.worker·mammoth·jspdf 4개 로드 ✔ 재현 |
| 6 | unlocated 표시 | GREEN | showResult() 실경로에서 renderUnlocated() 호출, escapeHtml 적용 |
| 7 | 네이버 메타 | GREEN | 레이아웃에 1회 |
| 8 | 보안 | AMBER | 즉시 악용 가능한 XSS 없음. JSON-LD 에 </script>·따옴표·유니코드 주입 회귀 테스트 권장 |

## Claude 판단
- RED 는 사실이다. 파일이 밖으로 나가지는 않지만 "제3자 스크립트 없음"은 거짓 문장이다. 신분증을 다루는 화면에서 이 문장이 틀리면 신뢰 전체가 흔들린다.
- 고치는 방향: **라이브러리 4개를 자체 호스팅**(public/safe/vendor/)으로 옮겨 문장을 참으로 만든다. 문장만 고치는 것보다 낫다 — cdnjs 에도 접속 IP 가 남지 않게 되고, CDN 장애에도 도구가 돈다.
- AMBER 1(브레드크럼)·3(키 형식 검증)은 작아서 S11c 에 함께. AMBER 1 의 author/og:site_name 브랜드 통일과 AMBER 8 회귀 테스트는 S12 백로그.
