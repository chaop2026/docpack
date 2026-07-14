# SafeFile → SlimFile(Rails) 연동 가이드

작업은 4단계이고, 전부 합쳐 30분이면 끝납니다.

## 1단계 — 파일 배치

이 패키지의 파일을 Rails 프로젝트의 같은 위치에 복사합니다.

    public/safe/index.html                          → 그대로 복사
    app/controllers/api/safe_scan_controller.rb     → 그대로 복사
    config/routes_snippet.rb                        → 내용을 기존 config/routes.rb 안에 붙여넣기

`public/` 아래 파일은 Rails가 자동으로 서빙하므로, 이것만으로
slimfile.net/safe/ 페이지가 열립니다. (AI 검사 제외한 모든 기능이 이 시점부터 작동)

## 2단계 — API 키 설정

Anthropic 콘솔(console.anthropic.com)에서 API 키를 발급받아
서버 환경변수로 등록합니다. 절대 코드나 HTML에 직접 넣지 마세요.

    # 예: Heroku
    heroku config:set ANTHROPIC_API_KEY=sk-ant-xxxx

    # 예: 일반 서버 (.env 또는 systemd 환경변수)
    ANTHROPIC_API_KEY=sk-ant-xxxx

모델은 claude-haiku-4-5 (소형·저가)로 설정해 두었습니다.
개인정보 추출은 이 모델로 충분하며, 문서 1건당 비용은 원화 몇 원 수준입니다.
비용 상한이 걱정되면 Anthropic 콘솔에서 월 사용 한도(spend limit)를 걸어두세요.

## 3단계 — 메인 페이지에 메뉴 카드 추가

SlimFile 홈의 기능 카드 3개(Image Compress / PDF Conversion / Social Presets)와
같은 마크업을 하나 복사해서 내용만 바꿉니다. 예:

    <a href="/safe/">
      🔒 PRIVACY
      SafeFile
      문서 속 개인정보를 자동으로 찾아 가려 드립니다.   <!-- EN: Find & redact personal info in documents -->
      지우러 가기                                        <!-- EN: Redact now -->
    </a>

(실제 class 이름은 기존 카드의 것을 그대로 쓰면 디자인이 자동으로 맞습니다.)

## 4단계 — 배포 후 확인

배포하고 나서 아래 순서로 점검합니다.

1. slimfile.net/safe/ 접속 → 페이지가 뜨는지
2. "샘플 문서로 체험" → 정규식 탐지·마스킹·JPG 다운로드가 되는지 (서버 무관, 항상 작동)
3. "AI 정밀 검사" 버튼 → 이름/회사가 추가로 잡히는지 (2단계가 완료돼야 작동)
4. 터미널에서 직접 확인:

       curl -X POST https://slimfile.net/api/safe_scan \
         -H "Content-Type: application/json" \
         -d '{"text":"성명: 김민준, 회사: 한빛테크"}'

   → {"raw":"[{\"type\":\"name\",...}]"} 형태가 돌아오면 정상.

## 안전장치 (이미 코드에 포함됨)

- IP당 시간당 30회 AI 검사 제한 (초과 시 429) — 악의적 비용 폭탄 방지
- 텍스트 8,000자 / 이미지 base64 약 5MB 초과 시 거절
- Anthropic 장애 시 502 반환 → 프론트가 "잠시 후 다시 시도" 안내
- 문서 내용은 서버에 저장하지 않고 중계만 함 (로그에도 본문 미기록)

## 다음에 하면 좋은 것 (애드센스 승인 대비)

- /privacy (개인정보처리방침), /safe 전용 FAQ 문단
- 블로그 글 2~3개 (예: "이력서 보낼 때 가려야 할 정보", "주민번호 마스킹 기준")
- 루트에 ads.txt
