# STATE — DocPack / SlimFile

> 마지막 갱신: 2026-08-25
> 이 파일은 **자유롭게 덮어쓴다** — 과거 상태는 git 이 기억한다. **100줄 이내 유지**
> (넘으면 끝난 것을 지운다. 역사 보존용 파일이 아니다).

## 지금 상태

- Rails 8.0.4 + PostgreSQL 16, Hotwire/Propshaft/Importmap. Kamal 으로 `5.223.92.4` 에 배포,
  `https://slimfile.net` 서비스 중. 이미지 압축 · PDF 변환 · SNS 리사이즈 3개 서비스.
- **배포 파이프라인 복구 완료 (2026-08-25).** 3중 결함이 겹쳐 있었다 —
  ① Kamal 2 가 dotenv 자동 로딩을 제거해 `KAMAL_REGISTRY_PASSWORD` 가 빈 값
  ② ghcr.io PAT 만료 (`Bad credentials`)
  ③ 수정 과정에서 넣은 `${VAR:-default}` 를 Kamal 파서가 지원하지 않아 값이 손상.
  `.kamal/secrets` 가 `.env.production.local` 을 직접 읽도록 바꿔 해결. 이제 `kamal deploy` 만 치면 된다.
  자세한 내용은 CLAUDE.md "Deploy note" / "Kamal secrets parser trap" 절.
- `cb1e67d` 배포 완료 — 드래그앤드롭 기본동작 차단(`dragover`/`drop` preventDefault) + 진단 코드.
  라이브 검증됨: `curl -s https://slimfile.net/ | grep -c dragover` → `1`.
- **드래그앤드롭 원인 규명 + 수정 완료 (`6b42ec8`, 2026-08-25).** 원인은 두 겹이었다 —
  ① `upload_controller.js` 가 아예 없었다(뷰는 `data-controller="upload"` 를 선언 중이었으나 파일 부재)
  ② `#preview-area` 가 컨트롤러 엘리먼트의 형제라 Stimulus 가 타겟을 못 찾았다.
  결과적으로 네이티브 `<input>` 위에 정확히 떨어뜨렸을 때만 동작했고 점선 영역 나머지는 무반응이었다.
  이제 zone 전체가 드롭을 받고, 선택 파일이 개별 목록으로 표시된다(누적·중복제외·개별삭제·용량합계).
  프로덕션에서 34개 항목 검증 통과.
- **업로드 목록 시각 강화 완료 (2026-08-25).** 목록이 흰 드롭존 밑 흰 카드라 눈에 안 띄던 문제.
  카드 상단 4px 서비스 컬러 액센트 바 + 서비스 컬러 테두리(38%) + 서비스 연한 톤 헤더 밴드(55%),
  새 행에 520ms 진입 애니메이션(reduced-motion 별도 키프레임). 3개 서비스 페이지 모두 적용.
  Playwright 검증 60개 단언 통과. **다크모드는 이 앱에 없다** — `prefers-color-scheme` 가
  `app/`·`public/` 어디에도 없고, 다크로 띄워도 라이트와 바이트 단위로 동일하다.
- SafeFile(`public/safe/index.html`) v2 좌표 기반 마스킹. 최근 작업은 상단바 로고/네비 정리와
  서비스워커 stale-shell 고정, 포맷별 "PDF로 저장" 경로 추가.
- 블로그 자동화(주제 100개 → Claude API 생성 → MWF 09:00 KST 발행 + Gmail 알림)는
  2026-04 검증 이후 **실제 현재 동작 상태 확인 필요** (마지막 발행일·남은 주제 수 미확인).

## 다음 할 일

1. **ghcr.io PAT 재발급.** 2026-08-25 디버깅 중 `od -c` 로 토큰을 평문 출력해 세션 기록에 남았다.
   교체 후 `.env.production.local` 과 `.env` 두 파일 모두 갱신 (두 파일은 같은 값을 유지해야 함).
2. **진단 코드 제거.** `app/views/layouts/application.html.erb` 의 `window.__jsErrors` 수집기와
   `params[:debug]` 로 걸린 `alert()` 블록은 임시다. 원인 규명이 끝났으므로 이제 지워도 된다.
   `dragover`/`drop` preventDefault 자체는 남긴다.
3. **업로드 목록 실기기 확인.** 자동 검증은 통과했으나 실제 모바일 Safari/Chrome 에서
   드롭·파일 선택·긴 파일명 생략을 눈으로 한 번 볼 것. 시각 강화분(액센트 바·진입 애니메이션)도
   같이 본다. `color-mix` 미지원 구형 브라우저에서는 테두리가 중립 회색으로 내려앉는 게 정상이다.
4. **블로그 자동화 현재 상태 점검.** `kamal app exec 'bin/rails runner "puts Post.group(:status).count; puts BlogTopic.where(used: false).count"'`
   로 발행 현황과 잔여 주제 확인. 2026-04-07 SolidQueue/SMTP 수정 이후 재검증한 기록이 없다.

## 막힌 것 / 기다리는 것

- 없음. (1번 PAT 재발급은 사람이 GitHub 에서 직접 해야 하지만 현재 배포를 막고 있지는 않다 —
  지금 토큰은 유효하며 만료 전까지 동작한다.)
