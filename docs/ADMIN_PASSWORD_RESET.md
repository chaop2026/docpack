# 관리자 비밀번호를 잊었을 때 (S15 · 2026-11-07)

`/admin` 로그인 비밀번호를 새 값으로 바꾸는 절차다. 도구는 `bin/admin-password-reset` 하나이고,
**새 비밀번호를 화면에 출력하지 않는다** — 클립보드로만 받아서 Bitwarden 에 저장한다.

> 🔴 **비밀번호는 맥북의 `.env.production.local` 에만 있다.** 이 파일은 git 에 없고
> (`.gitignore` 의 `/.env*`), 이 저장소는 **PUBLIC** 이다. 비밀번호를 터미널에 출력하거나
> 커밋 메시지·이슈·채팅에 붙여넣지 않는다.

---

## 1. 비밀번호를 모를 때 — 교체한다 (알아내지 않는다)

지금 값이 무엇인지 알아내려 하지 말고 **새 값으로 바꾼다.** 서버에서 꺼내 보는 명령
(`kamal app exec 'printenv ADMIN_PASSWORD'`)은 값을 터미널 스크롤백에 영구히 남기므로
쓰지 않는다. 교체가 더 빠르고 더 안전하다.

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac · 일반 터미널 ·
> 비밀번호 교체

이동:

```
cd /Users/sunghoon/Projects/docpack
```

실행:

```
bin/admin-password-reset
```

마지막에 `지금 배포할까요? (y/N)` 를 묻는다. **배포하지 않으면 서버는 계속 옛 값으로
동작한다** — 파일만 바꿔도 로그인은 그대로다. 아래 3절을 참고해서 답한다.

---

## 2. 도구가 하는 일 (순서대로)

| 단계 | 하는 일 | 실패하면 |
|---|---|---|
| 1 | `.gitignore` 가 `.env.production.local` 과 백업(`.env*.bak-*`)을 무시하는지 확인 | 규칙을 추가한다. git 작업 트리가 아니면 **추가하지 않고** 알린다 |
| 2 | 교체 전 상태 기록 — 줄 수 · `ADMIN_PASSWORD` 외 나머지 줄의 SHA-256 · 파일 권한 | `ADMIN_PASSWORD` 줄이 2개 이상이면 **중단**(어느 줄이 유효한지 기계가 정할 수 없다) |
| 3 | 새 비밀번호 생성 — `openssl rand`(암호학적 난수) → 영숫자 32자 | 24자 미만이면 중단 |
| 4 | `.env.production.local.bak-YYYYmmdd-HHMMSS` 로 백업 + 원본과 바이트 동일 확인 | 다르면 **교체하지 않는다**. 원본은 그대로 |
| 5 | `ADMIN_PASSWORD` 줄만 교체하고 **검증** — 나머지 줄 SHA-256 동일 · 줄 수 · 그 줄이 정확히 1개 · 기록된 값의 길이 | 하나라도 어긋나면 교체하지 않고, 검토용 파일 경로를 알린다 |
| 6 | 새 값을 `pbcopy` 로 클립보드에 복사 | 실패하면 파일에서 직접 꺼내라고 안내 |

**하지 않는 일도 설계의 일부다:**

- **값을 출력하지 않는다.** 길이와 문자 종류만 보고한다. 터미널 스크롤백은 영구적이다.
- **파일을 지우지 않는다.** 이 스크립트에는 `rm` 이 없다. 실패하면 중간 파일을 **남긴 채**
  경로를 알리고, 되돌릴 수 없는 삭제는 사람이 한다
  (`~/.claude/CLAUDE.md` 「삭제 안전 정책」).
- **다른 줄을 손대지 않는다.** 같은 파일에 `RAILS_MASTER_KEY`·`GMAIL_PASSWORD`·
  `KAMAL_REGISTRY_PASSWORD` 가 함께 있다. 교체 전후 해시를 대조하지 않으면 그 중 하나가
  망가져도 **다음 배포에서야** 드러난다.
- **개발 폴더에서 배포하지 않는다.** 3절.

⚠️ 파일의 **마지막 줄에 개행이 없으면** 교체본에는 개행 1바이트가 추가된다. 유일하게
`ADMIN_PASSWORD` 밖의 바이트가 바뀌는 경우이므로, 스크립트가 그렇다고 말한다.

---

## 3. 배포 — `y` 와 `N` 중 무엇을 누를까

**파일을 바꾼 것만으로는 아무것도 바뀌지 않는다.** 서버 컨테이너는 배포 시점의 환경변수를
들고 있으므로, 새 비밀번호는 다음 `kamal deploy` 때 서버에 전달된다.

전역 규칙(`~/.claude/CLAUDE.md` 「배포 폴더 분리」)에 따라 **운영 배포는
`~/Projects/docpack-deploy` 배포 전용 폴더에서만** 한다. 개발 폴더에서는 하지 않는다.

> ⚠️ **2026-11-07 현재 `~/Projects/docpack-deploy` 가 없다.** 그래서 `y` 를 눌러도
> 스크립트는 배포하지 않고, 폴더를 만드는 방법을 알린다. 만들기 전에는 배포 금지다.

### 배포 전용 폴더가 아직 없을 때 — 먼저 만든다

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects` — 로컬 Mac · 일반 터미널 ·
> 배포 전용 폴더 생성

이동:

```
cd /Users/sunghoon/Projects
```

실행:

```
git clone /Users/sunghoon/Projects/docpack /Users/sunghoon/Projects/docpack-deploy
```

비밀값은 **복사하지 않고 심볼릭 링크**로 쓴다(두 벌이 되면 한쪽만 교체된다):

```
ln -s /Users/sunghoon/Projects/docpack/.env.production.local /Users/sunghoon/Projects/docpack-deploy/.env.production.local
```

### 배포

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac ·
> 일반 터미널 · 운영 배포

이동:

```
cd /Users/sunghoon/Projects/docpack-deploy
```

실행 (`&&` 로만 잇는다 — 앞 단계가 실패하면 배포가 돌지 않아야 한다):

```
git fetch && git checkout --detach origin/main && git status --porcelain && kamal deploy
```

`git status --porcelain` 이 **아무것도 출력하지 않아야** 한다. 한 줄이라도 나오면 멈추고
내용을 확인한다.

> 📌 `.kamal/secrets` 가 `.env.production.local` 을 스스로 읽는다. **배포 전에
> `source .env` 를 하지 않는다** — 그 파일에는 로컬 개발용 `DB_PASSWORD=postgres` 가 있어
> 배포를 오염시킨다 (CLAUDE.md 「Deploy note」).

---

## 4. 배포 후 확인 — 값을 출력하지 않는 방법

1. `https://slimfile.net/admin/login` 에서 **새 비밀번호로** 로그인 → `/admin/banners` 로 들어가야 한다.
2. **옛 비밀번호로** 로그인 → `비밀번호가 올바르지 않습니다.` 가 나와야 한다.
   (여기서 들어가진다면 배포가 안 된 것이다.)
3. 공개된 기본값으로 로그인 → 역시 거부돼야 한다.
   2026-11-07 이전에는 `ADMIN_PASSWORD` 가 비어 있으면 `docpack2025` 로 로그인이
   **됐다** — 이 저장소의 git 이력에 적혀 있는 값이다. 지금은 비어 있으면 아무도 못 들어간다.

서버에서 확인하고 싶다면 **값이 아니라 설정 여부만** 본다:

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac ·
> 일반 터미널 · 서버의 ADMIN_PASSWORD 설정 여부 확인(값 미출력)

이동:

```
cd /Users/sunghoon/Projects/docpack-deploy
```

실행:

```
kamal app exec 'ruby -e "puts ENV[%q(ADMIN_PASSWORD)].to_s.empty? ? %q(EMPTY) : %q(SET len=) + ENV[%q(ADMIN_PASSWORD)].length.to_s"'
```

`SET len=32` 가 나와야 한다. `EMPTY` 면 로그인이 전부 거부된다(로그인 화면에
`관리자 비밀번호가 설정되지 않았습니다.` 가 뜬다).

---

## 5. 되돌리기

교체 직후 백업이 같은 폴더에 있다. 값을 Bitwarden 에 저장하지 못했다면 이 파일이
유일한 기록이다.

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack` — 로컬 Mac · 일반 터미널 ·
> 백업 확인

이동:

```
cd /Users/sunghoon/Projects/docpack
```

백업 목록 (값은 출력되지 않는다):

```
ls -la .env.production.local.bak-*
```

되돌리려면 그 파일을 `.env.production.local` 로 복사한 뒤 다시 배포한다.
**백업 파일을 지우는 것은 사람이 한다** — 에이전트도 스크립트도 지우지 않는다.

---

## 6. 로그인 쪽이 함께 바뀐 것 (S15)

| 바뀐 것 | 왜 |
|---|---|
| `ADMIN_PASSWORD` 미설정 시 **로그인 거부** | 전에는 `docpack2025` 로 폴백했다. 공개 저장소에 적힌 값이다 |
| 비교를 `ActiveSupport::SecurityUtils.secure_compare` 로 | 타이밍으로 글자를 하나씩 맞출 수 없게 |
| **1분 5회** 상한, 초과 시 `429` | 무차별 대입. 비밀번호를 **읽기 전에** 막는다 |
| 로그인 성공 시 `reset_session` | 세션 고정 공격 — 공격자가 심어둔 세션 id 가 인증된 id 로 승격되지 않게 |
| 세션 **12시간** 만료 (발급 시각 기준) | 열어둔 탭이 영원히 살아 있지 않게. 슬라이딩이 아니라 발급 기준이다 |
| 발급 시각이 없는 세션은 **만료 취급** | 2026-11-07 이전 세션에는 시각이 없다. 「언제 발급됐는지 모른다」의 정직한 해석은 「유효하다고 말할 수 없다」다 |

세션이 만료되면 조용히 로그인 화면으로 돌아간다. `/admin/jp/packages/:ep/preview` 는
만료 시 **404** 다(그 주소가 존재한다는 사실조차 알리지 않는다) — 로그아웃 상태와 같은 응답이다.

테스트: `test/integration/admin_auth_test.rb`(22) · `test/scripts/admin_password_reset_test.rb`(21).
