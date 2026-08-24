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
- SafeFile(`public/safe/index.html`) v2 좌표 기반 마스킹. 최근 작업은 상단바 로고/네비 정리와
  서비스워커 stale-shell 고정, 포맷별 "PDF로 저장" 경로 추가.
- 블로그 자동화(주제 100개 → Claude API 생성 → MWF 09:00 KST 발행 + Gmail 알림)는
  2026-04 검증 이후 **실제 현재 동작 상태 확인 필요** (마지막 발행일·남은 주제 수 미확인).

## 다음 할 일

1. **ghcr.io PAT 재발급.** 2026-08-25 디버깅 중 `od -c` 로 토큰을 평문 출력해 세션 기록에 남았다.
   교체 후 `.env.production.local` 과 `.env` 두 파일 모두 갱신 (두 파일은 같은 값을 유지해야 함).
2. **진단 코드 제거.** `app/views/layouts/application.html.erb` 의 `window.__jsErrors` 수집기와
   `params[:debug]` 로 걸린 `alert()` 블록은 임시다. 드래그앤드롭 원인 규명이 끝나면 지운다.
   `dragover`/`drop` preventDefault 자체는 남긴다.
3. **드래그앤드롭 이슈 결론 내기.** `?debug` 로 실제 기기에서 UA·Stimulus 로드 여부·importmap 지원·
   JS 에러를 확인한다. 무엇이 문제였는지 아직 기록되지 않았음 — 확인 후 DECISIONS.md 에 남길 것.
4. **블로그 자동화 현재 상태 점검.** `kamal app exec 'bin/rails runner "puts Post.group(:status).count; puts BlogTopic.where(used: false).count"'`
   로 발행 현황과 잔여 주제 확인. 2026-04-07 SolidQueue/SMTP 수정 이후 재검증한 기록이 없다.

## 막힌 것 / 기다리는 것

- 없음. (1번 PAT 재발급은 사람이 GitHub 에서 직접 해야 하지만 현재 배포를 막고 있지는 않다 —
  지금 토큰은 유효하며 만료 전까지 동작한다.)
