# 배포 절차서 — slimfile.net / Rails 8.1.4.1 (2026-11-08)

배포 대상 커밋 **`9da567f`** (`chore: upgrade Rails to 8.1.x security patch (8.0 EOL 2026-11-07)`).
**실행은 사람(Justin)이 한다.** 이 문서를 쓴 세션은 운영 서버·운영 DB·kamal 명령을 하나도
실행하지 않았다 — 모든 명령은 이 리포의 기록과 설정 파일에서만 끌어온 것이다.

위에서부터 순서대로 붙여넣는다. 각 단계의 **멈출 조건**을 넘기지 않는다.

## 이 배포가 바꾸는 것 (왜 이 확인들이 필요한가)

| 변경 | 그래서 확인하는 것 |
|---|---|
| Rails 8.0.5.1 → 8.1.4.1 (전체 프레임워크 교체) | ⑤-1 버전 · ⑤-2 DB 연결 · ⑤-3 SMTP · ⑤-5 에셋 |
| `app:update` 가 만든 Active Storage 마이그레이션 3건을 **커밋하지 않기로** 했다 | **② 읽기 전용 SQL 3건** — 그 판단의 유일한 미검증 전제가 「프로덕션 스키마가 dev 와 같다」다 |
| 컨테이너 부팅 시 `db:prepare` 가 **자동 실행**된다 | **③ pending 0** — 모르는 마이그레이션이 있으면 배포가 그것을 **자동으로 적용**한다 |

> 🔴 **`db:prepare` 는 배포하면 저절로 돈다.** `Dockerfile` 의
> `CMD ["./bin/thrust", "./bin/rails", "server"]` 가 `bin/docker-entrypoint` 의
> `[ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]` 조건에 맞기 때문이다.
> 그래서 ③ 은 「확인해 두면 좋은 것」이 아니라 **배포 전에 반드시 봐야 하는 것**이다.

---

## ⓪ 준비 — 배포 전용 폴더와 롤백 대상

### ⓪-a 🔴 배포 전용 폴더가 없다 — 만들기 전에는 배포하지 않는다

전역 규칙(2026-11-03 · 대표 결정): **운영 배포는 `~/Projects/<프로젝트>-deploy` 배포 전용
폴더에서만 한다. 개발 폴더에서 배포하지 않는다.** 실측: `~/Projects/docpack-deploy` **없음**.

이 리포의 과거 기록(`docs/jp/s8b_report.md` §5, `docs/jp/s10_report.md`)은 개발 폴더
`/Users/sunghoon/Projects/docpack` 에서 `kamal` 을 돌렸다. 그 기록은 2026-10-25 로
**규칙보다 앞선다** — 이 배포는 새 규칙을 따른다.

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects` — **로컬 Mac, 일반 터미널**
> — 배포 전용 폴더를 만든다(최초 1회)

이동:

```
cd /Users/sunghoon/Projects
```

실행:

```
git clone https://github.com/chaop2026/docpack.git docpack-deploy && cd docpack-deploy && git log --oneline -1
```

비밀값은 **개발 폴더 것을 심볼릭 링크로** 쓴다(복사·출력 금지). `.kamal/secrets` 는 git 에
추적되므로 클론에 이미 있고, 그 파일이 읽는 것은 `.env.production.local` **하나**다
(실측: `.kamal/secrets` 안의 `.env` 참조는 `.env.production.local` 뿐).

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 비밀 파일 링크

```
ln -s /Users/sunghoon/Projects/docpack/.env.production.local /Users/sunghoon/Projects/docpack-deploy/.env.production.local && ls -l .env.production.local && git status --porcelain && echo "CLEAN-IF-EMPTY-ABOVE"
```

**기대 결과**: 심볼릭 링크 1줄이 보이고, `git status --porcelain` 출력이 **비어 있다**
(`.env.production.local` 은 gitignore 되어 있음 — 실측 확인).

**멈출 조건 (굵게)**:
- **`git status --porcelain` 에 `.env.production.local` 이 나타나면 멈춘다** — gitignore 가
  깨진 것이고, 그대로 두면 비밀 파일이 공개 저장소에 커밋될 수 있다.
- **클론한 `git log` 가 `9da567f` 를 포함하지 않으면 멈춘다**(push 가 안 됐다는 뜻).

### ⓪-b 롤백 대상 버전을 **먼저** 적어 둔다

`kamal rollback` 은 **버전 인자가 필수**다(kamal 2.11.0 `lib/kamal/cli/main.rb:82-83`
— `desc "rollback [VERSION]"` / `def rollback(version)`). 배포 후에 「원래 버전」을
찾으려 하면 늦다.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널

```
kamal app version && kamal app containers
```

**기대 결과**: 현재 돌고 있는 버전(git SHA)이 출력된다. **그 값을 메모한다** — ⑥ 의
`<이전버전>` 이 그것이다.

**멈출 조건**: **출력이 비어 있거나 서버에 접속하지 못하면 멈춘다.** 롤백 대상을 모르는
상태로 배포하지 않는다.

---

## ① 배포 전 운영 DB 백업

방법은 이 리포에 기록된 것을 그대로 쓴다(`docs/jp/s8b_report.md` §5 ⓪ ·
실제 사용 기록 `docs/jp/s10_report.md`: `docpack_pre_s10_20261101_0715.sql.gz`).

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 운영 서버로 접속한다

이동 겸 접속:

```
ssh root@5.223.92.4
```

> **[기존 터미널]** 위 ssh 세션 안 (프롬프트 `root@...#`) — **원격 서버**, 홈 디렉터리
> — 배포 직전 전체 덤프

```
docker exec -i $(docker ps -qf name=docpack-db) pg_dump -U docpack docpack_production | gzip > ~/docpack_pre_rails81_$(date +%Y%m%d_%H%M).sql.gz && ls -lh ~/docpack_pre_rails81_*.sql.gz
```

**기대 결과**: `.sql.gz` 파일 1개가 **0 바이트가 아닌** 크기로 보인다.

**멈출 조건 (굵게)**:
- **파일 크기가 0 이거나 `ls` 가 아무것도 못 찾으면 멈춘다.**
- **`docker ps -qf name=docpack-db` 가 비면 멈춘다** — DB 컨테이너 이름이 달라진 것이고,
  그 상태에서는 위 명령이 **빈 덤프를 만들고도 성공처럼 보인다**. `docker ps` 로 실제 이름을
  확인한 뒤 이 세션에 알려 주면 명령을 고쳐 준다.

백업이 되돌리는 것은 **DB 뿐**이다. 외부로 나간 것(메일·X 게시)은 덤프로 되돌아오지 않는다.

---

## ② 읽기 전용 확인 SQL 3건 — 마이그레이션 거부 판단의 전제

`docs/review/CROSS_REVIEW_TRIAGE_2026-11-07_rails81.md` §2 의 내용 그대로다.
**`SELECT` 만 있고 쓰기 문장은 없다.**

> **[기존 터미널]** 위 ssh 세션 안 (프롬프트 `root@...#`) — **원격 서버**
> — SQL 1/3: 통합 마이그레이션이 적용돼 있는가

```
docker exec -i $(docker ps -qf name=docpack-db) psql -U docpack -d docpack_production -c "SELECT version FROM schema_migrations WHERE version = '20260324143948';"
```

> **[기존 터미널]** 위 ssh 세션 안 (프롬프트 `root@...#`) — **원격 서버**
> — SQL 2/3: `service_name` 은 NOT NULL, `checksum` 은 nullable 인가

```
docker exec -i $(docker ps -qf name=docpack-db) psql -U docpack -d docpack_production -c "SELECT column_name, is_nullable FROM information_schema.columns WHERE table_name = 'active_storage_blobs' AND column_name IN ('service_name','checksum') ORDER BY column_name;"
```

> **[기존 터미널]** 위 ssh 세션 안 (프롬프트 `root@...#`) — **원격 서버**
> — SQL 3/3: variant 레코드 테이블이 존재하는가

```
docker exec -i $(docker ps -qf name=docpack-db) psql -U docpack -d docpack_production -c "SELECT to_regclass('public.active_storage_variant_records');"
```

**기대 결과 — 셋 전부가 아래와 같아야 한다**:

| # | 쿼리 | 기대 |
|---|---|---|
| 1 | `schema_migrations` 의 `20260324143948` | **1행** (`20260324143948`). 0행이면 통합 마이그레이션이 적용돼 있지 않다 |
| 2 | `active_storage_blobs` 컬럼 | `checksum` → `is_nullable = YES` · `service_name` → `is_nullable = NO` (2행) |
| 3 | `to_regclass(...)` | **`active_storage_variant_records`** (NULL 이 아니다) |

**멈출 조건 (굵게)**:
> 🔴 **셋 중 하나라도 기대와 다르면 — 배포 중단 · 이 세션에 결과 전달.**
> 세 값은 「`app:update` 가 복사한 Active Storage 마이그레이션 3건을 커밋하지 않는다」는
> 판단의 **전제**다. 전제가 깨지면 그 3건이 프로덕션에서 필요하다는 뜻이고, 판단을 다시
> 해야 한다. 출력을 그대로 붙여 주면 다음 단계를 잇는다.
> 특히 **2번이 `service_name = YES` 로 나오거나 3번이 `NULL` 이면 절대 배포하지 않는다** —
> 부팅 시 `db:prepare` 가 자동으로 도는 구조이므로, 배포가 곧 스키마 변경이 된다.

---

## ③ pending 마이그레이션 0 확인

> **[새 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — **로컬 Mac, 일반 터미널**
> — ssh 세션은 그대로 두고 로컬에서 실행한다

이동:

```
cd /Users/sunghoon/Projects/docpack-deploy
```

실행:

```
kamal app exec --reuse 'bin/rails db:migrate:status' 2>&1 | grep -E "^ *(up|down)" | grep -c "^ *down" ; kamal app exec --reuse 'bin/rails db:migrate:status' 2>&1 | grep -E "^ *down" || echo "NO DOWN MIGRATIONS"
```

**기대 결과**: 첫 줄이 **`0`**, 그다음 **`NO DOWN MIGRATIONS`**.

**멈출 조건 (굵게)**:
- **`down` 상태가 1건이라도 나오면 멈춘다.** 배포하면 부팅 시 `db:prepare` 가 그것을
  **자동 적용**한다 — 내용을 모르는 마이그레이션이 운영 스키마를 바꾸게 된다.
- **위 ② 에서 본 3건(`20261107150121`~`150123`)이 `down` 으로 보이면 멈춘다.** 그 세 파일은
  일부러 커밋하지 않았으므로 배포 이미지에 **없어야** 한다. 보인다면 어딘가에서 커밋된 것이다.

> ⚠️ **«확인 필요» — 멀티 DB 출력 모양.** `config/database.yml` 의 production 은
> `primary`/`queue`/`cache`/`cable` 4개이고(전부 같은 물리 DB `docpack_production`,
> `migrations_paths` 만 다르다), `db/queue_migrate`·`db/cache_migrate`·`db/cable_migrate`
> 디렉터리는 **저장소에 존재하지 않는다**(실측). 그래서 `db:migrate:status` 가 DB 별로 나뉘어
> 출력되는지, 혹은 primary 만 보고하는지는 **이 리포의 기록에 없다.** 출력이 위 grep 과 모양이
> 다르면 전체 출력을 그대로 붙여 주면 명령을 고쳐 준다. 추측으로 적지 않았다.

---

## ④ 배포

이 리포가 실제로 써 온 형태다 — CLAUDE.md "Deploy note (updated 2026-08-25)":
**`kamal deploy` 만 치면 된다.** `.kamal/secrets` 가 `.env.production.local` 을 스스로 읽는다.

> 🔴 **`source .env` 를 먼저 하지 않는다.** `.env` 에는 로컬 개발용 `DB_PASSWORD=postgres` 가
> 들어 있어 배포를 오염시킨다(CLAUDE.md 에 기록된 실제 사고).

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 배포할 커밋으로 detach 한 뒤 배포. **명령은 `&&` 로만 잇는다**(`;` 로 이으면 앞 단계가
> 실패해도 배포가 돈다 — 전역 규칙)

```
git fetch origin && git checkout --detach 9da567f && git status --porcelain && git log --oneline -1
```

**기대 결과**: `HEAD detached at 9da567f`, `git status --porcelain` 출력 **비어 있음**,
로그 1줄이 `9da567f chore: upgrade Rails to 8.1.x security patch (8.0 EOL 2026-11-07)`.

**멈출 조건**: **`git status --porcelain` 에 한 줄이라도 나오면 멈춘다** — 배포 폴더에
미커밋 변경이 있다는 뜻이고, 배포 폴더는 코드 수정을 하지 않는 곳이다.

위 출력이 기대와 같을 때만 — **그때만** 아래를 실행한다.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 실제 배포. 앞 블록의 `git status` 가 비어 있었을 때만 실행한다

```
kamal deploy
```

**기대 결과**: 빌드 → 푸시 → 부팅이 끝나고 오류 없이 종료.

**멈출 조건 (굵게)**:
- **`denied: denied` 로 레지스트리 인증이 실패하면 멈춘다.** CLAUDE.md 의
  "Kamal secrets parser trap" 절이 그 증상을 다룬다 — 값이 틀린 것과 토큰이 만료된 것이
  같은 메시지로 나온다. 값을 출력해 보지 말고 그 절의 길이 비교 방법을 쓴다.
- **헬스체크가 통과하지 못해 kamal 이 롤백/중단하면 ⑥ 으로 간다.**

---

## ⑤ 배포 후 확인

전부 **로컬 Mac, 일반 터미널**, 폴더 `/Users/sunghoon/Projects/docpack-deploy` 에서 실행한다.

> ℹ️ **이 앱에는 별도 worker 컨테이너가 없다.** `config/deploy.yml` 의 `servers` 에는 `web`
> 역할 하나뿐이고 `SOLID_QUEUE_IN_PUMA: true` 라 Solid Queue 가 Puma 안에서 돈다. 그래서
> 「web/worker 각각」이 아니라 **app 컨테이너 한 곳**을 보는 것이 맞다.

### ⑤-1 Rails 버전이 실제로 8.1.4.1 인가

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "puts({rails: Rails.version, ruby: RUBY_VERSION, env: Rails.env, defaults: Rails.application.config.loaded_config_version}.inspect)"'
```

**기대 결과**: `rails: "8.1.4.1"`, `ruby: "3.3.9"`, `env: "production"`, `defaults: 8.0`
(`load_defaults` 는 **의도적으로 8.0 유지** — 8.1 전환은 별도 작업이다).

> ℹ️ 이 네 호출은 dev 컨테이너에서 **실제로 실행해 동작을 확인**했다. 처음에는
> `config.load_defaults_version` 으로 썼는데 **그런 메서드가 없어** `NoMethodError` 가 났다 —
> 올바른 접근자는 `loaded_config_version` 이다. 배포 당일에 깨지는 명령을 적지 않으려고
> `SolidCable::Message`(존재 확인) 와 `ActionMailer::Base.mail(...)`(빌드만 확인, 발송 안 함)
> 도 같은 방식으로 확인했다.

**멈출 조건**: **`rails` 가 8.1.4.1 이 아니면 멈춘다** — 옛 이미지가 돌고 있다.

### ⑤-2 queue / cache / cable DB 연결

4개 연결(`primary`·`queue`·`cache`·`cable`)은 전부 같은 물리 DB `docpack_production` 를
가리킨다(`config/database.yml` 실측). 확인은 각 연결을 **실제로 써 보는 것**이다.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "k=%q{deploy_probe_20261108}; Rails.cache.write(k, 1, expires_in: 60); puts({primary: ActiveRecord::Base.connection.select_value(%q{select 1}), queue_jobs: SolidQueue::Job.count, cache_roundtrip: Rails.cache.read(k), cable_messages: SolidCable::Message.count}.inspect)"'
```

**기대 결과**: `primary: 1`, `queue_jobs` 는 정수, `cache_roundtrip: 1`, `cable_messages` 는 정수.

**멈출 조건**: **네 값 중 하나라도 예외를 던지거나 `cache_roundtrip` 이 `nil` 이면 멈춘다.**
`nil` 이면 cache DB 연결이 끊긴 것이다(쓰기는 됐는데 읽기가 안 되는 경우도 포함).

> ℹ️ 이 명령은 cache DB 에 60초 만료 키 하나를 쓴다. 애플리케이션의 평범한 캐시 동작이고
> 스키마는 건드리지 않는다 — 다른 셋은 순수 읽기다.

### ⑤-3 SMTP 1통

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널

```
kamal app exec --reuse 'bin/rails runner "ActionMailer::Base.mail(to: %q{chaop2@gmail.com}, from: ENV.fetch(%q{GMAIL_USERNAME}), subject: %q{[SlimFile] Rails 8.1.4.1 deploy SMTP check}, body: %q{Sent from production after the Rails 8.1.4.1 deploy.}).deliver_now; puts %q{SENT}"'
```

**기대 결과**: `SENT` 가 출력되고 `chaop2@gmail.com` 으로 메일 1통이 도착한다.
`config/environments/production.rb:64` 가 `raise_delivery_errors = true` 이므로 **실패하면
조용히 넘어가지 않고 예외가 난다**.

**멈출 조건**: **`SMTPAuthenticationError 535-5.7.8` 이 나오면 멈춘다** — 2026-04-07 에
`GMAIL_PASSWORD` 가 빈 값이어서 똑같이 났던 증상이다(CLAUDE.md 기록). 배포 자체는 살아 있지만
모든 알림 메일이 죽은 상태이므로 고치기 전에는 완료로 보지 않는다.

> ⚠️ **«확인 필요» — 이 명령 자체는 리포 기록에 없다.** 이 리포에는 SMTP 확인용 rake 태스크가
> 없다(실측: `lib/tasks/` 에 메일 발송 태스크 0건). 위 명령은 **기록된 설정만으로 조립**한
> 것이다 — 수신자 `chaop2@gmail.com` 은 `app/mailers/blog_mailer.rb` 의 모든 `mail(to:)` 에서,
> 발신자는 `app/mailers/application_mailer.rb` 의 `default from: ENV.fetch("GMAIL_USERNAME", …)`
> 에서 가져왔다. 기존 메일러를 쓰지 않은 이유는 `BlogMailer` 의 모든 메서드가 실제 Post 를
> 요구해 **DB 상태에 의존**하기 때문이다. 이 형태가 마음에 들지 않으면 알려 주면 바꾼다.

### ⑤-4 업로드 → 다운로드 (그리고 variant 에 대한 정정)

> ⚠️ **«확인 필요 / 해당 없음» — 「variant 생성」은 이 앱에 코드 경로가 없다.**
> 교차검증 체크리스트는 "업로드·다운로드·variant 생성 1회"를 적었지만, **실측 결과 이 앱은
> Active Storage 의 variant/representation 을 어디에서도 쓰지 않는다**
> (`app/`·`lib/` 전체에 `.variant`·`representation`·`processed` 호출 0건). 이미지 변환은
> `ImageProcessing::Vips` 를 **서비스에서 직접** 호출해 결과를 `result_file` 로 저장한다
> (`app/services/image_compressor.rb` 등). 그래서 variant 를 「생성해 보는」 단계는 만들 수
> 없다 — 없는 기능을 확인하는 단계를 적는 것은 거짓이다.
> `active_storage_variant_records` **테이블의 존재**는 ② 3번에서 이미 확인한다(그게 이번
> 마이그레이션 판단에서 실제로 걸려 있던 것이다).

대신 **제품의 실제 경로**를 사람이 브라우저로 1회 확인한다.

> **[읽기만]** 브라우저 (시크릿 창 권장) — 로컬 Mac

1. `https://slimfile.net/compress` 열기 → 이미지 1장 업로드 → 압축 실행
2. 결과 페이지에서 **다운로드** 버튼으로 파일 받기 → 받은 파일이 열리는지 확인
3. `https://slimfile.net/pdf` 와 `https://slimfile.net/social` 도 각 1회

**기대 결과**: 세 서비스 모두 업로드 → 처리 → 다운로드가 끝까지 되고, 받은 파일이 깨지지 않는다.

**멈출 조건 (굵게)**: **업로드가 500 으로 죽거나 다운로드 파일이 0 바이트면 멈춘다.**
이 경로는 `ImageProcessing::Vips`(1.14.0, 이번에 **올리지 않은** 젬)와 Active Storage
(8.1.4.1, **올린** 쪽)가 만나는 자리라 이번 업그레이드에서 가장 먼저 봐야 하는 곳이다.

### ⑤-5 에셋이 정상인가

Propshaft + `asset_path: /rails/public/assets`. 레이아웃은 `stylesheet_link_tag :app` 와
`javascript_importmap_tags` 를 쓴다(`app/views/layouts/application.html.erb:124-125`).

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 홈에서 실제 에셋 URL 을 뽑아 그 URL 을 직접 받아 본다

```
printf 'home '; curl -s -o /dev/null -w '%{http_code}\n' https://slimfile.net/ ; for u in $(curl -s https://slimfile.net/ | grep -oE '/assets/[A-Za-z0-9._-]+' | sort -u | head -5); do printf '%s ' "$u"; curl -s -o /dev/null -w '%{http_code}\n' "https://slimfile.net$u"; done
```

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 헬스 엔드포인트와 브랜드 정적 파일(과거 2회 404 났던 자리)

```
printf 'up '; curl -s -o /dev/null -w '%{http_code}\n' https://slimfile.net/up ; for f in icon-192.png icon.svg og_1200x630.png favicon.ico; do printf '%s ' "$f"; curl -s -o /dev/null -w '%{http_code}\n' "https://slimfile.net/safe/brand/$f"; done
```

**기대 결과**: 전부 **200**. 에셋 URL 이 **1개 이상** 추출돼야 한다.

**멈출 조건 (굵게)**:
- **에셋이 404 면 멈춘다** — precompile 이나 `asset_path` 가 깨진 것이다.
- **에셋 URL 이 0개 추출되면 그것도 멈출 조건이다.** 「0개 검사하고 전부 200」은 통과가 아니다
  (이 리포가 `canonical_sweep` 에서 한 번 당한 모양이다).
- **`/safe/brand/*` 가 404 면 멈춘다** — S8·S11 에서 파일 권한(700/600) 때문에 두 번 났던
  증상이다. 나면 `chmod -R a+rX public/safe/brand` 후 재배포한다.

---

## ⑥ 문제 시 롤백

kamal **2.11.0** 에서 확인한 형태다(`lib/kamal/cli/main.rb:82-99`, 컨테이너 안 젬 소스를
읽어 확인):
- `kamal rollback [VERSION]` — **VERSION 인자가 필수**다. 인자 없이 부르면 Thor 가 거부한다.
- 그 버전의 컨테이너가 서버에 남아 있어야 한다. 없으면 kamal 이
  `The app version '…' is not available as a container (use 'kamal app containers' …)` 를
  빨간 글씨로 출력하고 **아무것도 하지 않는다**.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — 먼저 되돌릴 수 있는 버전 목록을 본다

```
kamal app containers && kamal app version
```

**기대 결과**: ⓪-b 에서 메모한 이전 버전이 목록에 **보인다**.

그 다음, 메모한 버전으로 되돌린다.

> **[기존 터미널]** 폴더: `/Users/sunghoon/Projects/docpack-deploy` — 로컬 Mac, 일반 터미널
> — `<이전버전>` 을 ⓪-b 에서 적어 둔 git SHA 로 **바꿔서** 붙여넣는다. 이 문서가 그 값을
> 미리 채울 수 없는 이유는, 그것이 지금 서버에 무엇이 떠 있는지에만 달려 있고 이 세션은
> 운영 서버를 조회하지 않았기 때문이다 — 이 문서에서 값을 비워 둔 곳은 여기 하나뿐이다

```
kamal rollback <이전버전>
```

**기대 결과**: 그 버전의 컨테이너가 다시 부팅되고 `kamal app version` 이 그 값을 보고한다.

**멈출 조건 (굵게)**:
- **이전 버전이 `kamal app containers` 에 없으면 `kamal rollback` 을 시도하지 않는다.**
  그 경우의 복구는 「이전 커밋으로 detach 해서 다시 배포」다:
  `git checkout --detach <이전버전> && kamal deploy`.
- 🔴 **DB 는 롤백이 되돌리지 않는다.** 롤백은 애플리케이션 컨테이너만 바꾼다. 부팅 시
  `db:prepare` 가 이미 스키마를 바꿨다면 ① 의 덤프로 **사람이** 복원해야 한다.
  이 배포는 마이그레이션을 **포함하지 않으므로**(③ 에서 pending 0 을 확인한 전제) 정상
  경로에서는 스키마가 바뀌지 않는다 — 그래서 ③ 을 건너뛰면 안 된다.
- **메일·X 게시 등 외부로 나간 것은 어떤 롤백으로도 되돌아오지 않는다.**

---

## 이 문서에서 «확인 필요» 로 남긴 것

| 위치 | 무엇 | 왜 추측으로 채우지 않았나 |
|---|---|---|
| ⓪-a | **배포 전용 폴더 없음** | 전역 규칙(2026-11-03)은 전용 폴더를 요구하는데 `~/Projects/docpack-deploy` 가 **없다**. 과거 기록은 개발 폴더에서 배포했으나 그 기록이 규칙보다 앞선다. **만들기 전 배포 금지** |
| ③ | 멀티 DB `db:migrate:status` 출력 모양 | production 연결이 4개인데 `db/{queue,cache,cable}_migrate` 디렉터리가 **없다**. DB 별로 나뉘어 출력되는지가 리포 기록에 없다 |
| ⑤-3 | SMTP 확인 명령 | 리포에 메일 발송 태스크가 **0건**. 명령은 기록된 설정(수신자·발신자·SMTP)만으로 **조립**한 것이라고 밝혔다 |
| ⑤-4 | 「variant 생성」 | **해당 없음.** Active Storage variant/representation 호출이 `app/`·`lib/` 에 0건. 없는 기능의 확인 단계를 적지 않고, 실제 제품 경로로 대체했다 |
| ① · ② | ssh 사용자 `root@5.223.92.4` | 사용자 `root` 와 프롬프트 모양은 `docs/jp/s8b_report.md` §5 ⓪ 에서, 호스트는 `config/deploy.yml:7`·`STATE.md` 에서 가져와 **두 출처를 합쳤다**. 한 곳에 같이 적힌 기록은 없다 |

## 근거 (전부 이 리포 안)

`config/deploy.yml`(서버·accessory db·env·volumes·asset_path) ·
`Dockerfile`(CMD·USER 1000) · `bin/docker-entrypoint`(`db:prepare` 자동 실행 조건) ·
`config/database.yml`·`queue.yml`·`cache.yml`·`cable.yml`(4개 연결) ·
`CLAUDE.md`(Deploy note 2026-08-25 · Kamal secrets parser trap · SMTP 2026-04-07 사고 ·
Rails 8.1 업그레이드 절) · `docs/jp/s8b_report.md` §5(백업·`kamal app exec --reuse` 형태) ·
`docs/jp/s10_report.md`(실제 백업 파일명 선례) ·
`docs/review/CROSS_REVIEW_TRIAGE_2026-11-07_rails81.md` §2(확인 SQL 3건) ·
kamal 2.11.0 젬 소스 `lib/kamal/cli/main.rb`·`cli/app.rb`(rollback 인자·app 서브커맨드).
