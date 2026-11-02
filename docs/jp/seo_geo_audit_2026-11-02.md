# SafeFile JP — 검색(SEO)·AI 답변(GEO/AEO) 점검 (2026-11-02)

## 실측
| 항목 | 결과 |
|---|---|
| Google 색인 (Search Console, https://slimfile.net/ URL-prefix, chaop2) | 사이트 전체 67 색인 / 80 미색인, 3개월 클릭 18. **JP 페이지 전부 「Discovered – currently not indexed」**(크롤조차 안 됨) |
| 색인 요청(11-02 Claude) | /safe/jp/nyusatsu/ · /safe/jp/ai-mae/ · /safe/jp/honnin-kakunin/ · /ja/blog/jp-ep01-… → 4건 「Indexing requested」 |
| sitemap.xml | /safe/·/safe/jp/* 3곳·글 포함, robots.txt 정상 |
| GA4 SlimFile(531751767) | 지난 30일 16뷰, **/safe/ 계열 0** — /safe/ 정적 페이지에 gtag 없음(의도: 개인정보 도구). 대신 1st-party SafeEvent(landing_view·via·ep)가 측정 중 |
| llms.txt | SlimFile 압축 설명뿐, **SafeFile·일본어 페이지 언급 0** → AI가 SafeFile JP를 모름 |
| JSON-LD | nyusatsu: SoftwareApplication+FAQPage ✅ / ai-mae·honnin: FAQ 없음 / 글: Article(+FAQPage) ✅, publisher 로고·Organization sameAs 없음, BreadcrumbList 없음 / /ja/blog 목록: 없음 |
| 내부 링크 | 색인된 기존 페이지(홈·/safe/·KO 글)에서 /safe/jp/로 가는 링크 0 → "고아 페이지"라 크롤 우선순위 낮음 |
| Bing(ChatGPT 검색·Copilot의 원천) | 미등록 |

## 원인 판단
1. 외부 링크·내부 링크가 없어 Google이 크롤할 이유를 못 찾음(Discovered-not-indexed의 전형)
2. AI 답변 엔진이 읽는 llms.txt·Bing 인덱스에 SafeFile JP가 없음
3. ai-mae·honnin 랜딩은 질문형 구조(FAQ)가 없어 답변 인용 단위가 없음

## 조치
- 지금(Claude): Google 색인 요청 4건 ✅. Bing Webmaster(GSC 가져오기)는 Google 로그인 연결 승인 필요 → Justin 확인 대기
- S11(Claude Code): 아래 프롬프트 §GEO
- 측정: 2주 후(11-16) GSC에서 4 URL 색인 여부 재확인, 이후 매주 토요일 승인 메일 KPI에 「JP 색인 수」 추가
