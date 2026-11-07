# 교차검증 대조 — Rails 8.0.5.1 → 8.1.4.1 (2026-11-07)

패키지 [`CODEX_REVIEW_PACKAGE_2026-11-07_rails81.md`](CODEX_REVIEW_PACKAGE_2026-11-07_rails81.md)
리뷰어 codex-cli 0.146.0 (`--sandbox read-only`, 70,360 tokens)

**판정 분포: RED 0 · AMBER 3 · GREEN 5.** 배포를 막는 코드 결함 0건.
분류는 (a) 진짜 문제 / (b) 의견 차이 / (c) 오탐.

| # | 등급 | 지적 | 분류 | 조치 |
|---|---|---|---|---|
| 1 | AMBER | **내 거부 근거가 부정확하다** — 복사된 Active Storage 마이그레이션은 `column_exists?`·`if_not_exists: true` 가드가 있어 「PG::DuplicateColumn/DuplicateTable 로 실패」가 성립하지 않는다 | **(a)** | **수용.** 파일 3개를 직접 읽어 확인 — 전부 멱등 no-op 이 맞다. 패키지 §5 에 ~~취소선~~ + 정정 기록. **거부 결론은 유지하되 근거를 교체**(GO 범위·schema.rb version 상승·보안 패치 커밋은 DB 무변경이 기본값). 교환(다음 `app:update` 가 또 복사)도 명시 |
| 2 | AMBER | 운영 DB 미접촉 — `schema.rb` 는 덤프일 뿐 프로덕션 `schema_migrations` 를 증명하지 않는다. 배포 전 읽기전용 SQL 3개로 확인하라 | **(a)** | **수용.** 배포 전 사람 확인 항목으로 승격(아래 §2). 프로덕션 DB 는 이 세션에서 접촉하지 않았다 |
| 3 | AMBER | 8.1 이 **선행 대괄호 파라미터**와 **세미콜론 query separator** 의 구형 처리를 제거했다. 코드 검색으로는 외부 호출자를 알 수 없다 | **(a) 부분** | **실측해 범위를 좁혔다**: 우리 쪽 표면은 전부 평면 스칼라다(`params[:…]` 26개 전수 열거, 중첩·대괄호 0건), 세미콜론으로 쿼리를 만드는 코드 0건, `/api` 3개는 **JSON 전용 POST**(S6b 가 415 로 강제). → 우리 호출자는 무관. **제3자 발신만 코드로 확인 불가**하므로 그 부분만 사람 확인 항목으로 남긴다 |
| 4 | GREEN | `minitest "< 7"` 상한 유지가 맞다 | (b) 확인 | 조치 없음. 우리 판정과 일치 — 근거(railties 8.1.4.1 의 `else` 부재)를 내가 설치된 젬에서 직접 읽어 확인했고 codex 가 독립 확인 |
| 5 | GREEN | `load_defaults 8.0` 유지 가능. 8.1 제거 항목(`rails/console/methods`·다중경로 route·SQLite `:retries`·MySQL unsigned·Azure service·`Benchmark.ms`·`Time#since(Time)` 등) 사용 0건 | (b) 확인 | 조치 없음. 다만 **「565 테스트 + deprecation 0」은 강한 근거지만 증명은 아니다**는 지적을 수용해 남는 공백으로 적는다. 프로덕션은 `report_deprecations = false`(production.rb:46) 라 운영에서 경고가 보이지 않는다 |
| 6 | GREEN | `app:update` conflict 일괄 skip 은 적절. 단 **안전성의 근거는 「전부 skip 했다」가 아니라 §8 의 순정 8.1 diff** 다 | (b) 확인 | 조치 없음 — 이 구분이 정확하다. 그래서 §8 을 패키지에 넣었다 |
| 7 | GREEN | §8 의 Action Text/Trix 결론이 맞다 | (b) 확인 | 조치 없음 |
| 8 | GREEN | `freeze_time` 변경은 타당하며, 「Rails 8.1 우회가 아니라 기존 flaky 수정」이라는 설명도 정확하다 | (b) 확인 | 조치 없음. 양 스택 13/13 + 변이 프로브로 판별력 확인 |

## §2 배포 전 사람 확인 항목 (codex 목록 + 내 실측으로 좁힌 것)

프로덕션 DB 는 이 세션에서 **접촉하지 않았다.** 아래는 전부 **읽기 전용**이다.

1. **Active Storage 스키마 수렴 확인** — 거부 판단의 유일한 미검증 전제.
   ```sql
   SELECT version FROM schema_migrations WHERE version = '20260324143948';
   SELECT column_name, is_nullable FROM information_schema.columns
     WHERE table_name = 'active_storage_blobs' AND column_name IN ('service_name','checksum');
   SELECT to_regclass('public.active_storage_variant_records');
   ```
   기대: 통합 마이그레이션 기록 **존재** · `service_name` = `NO` · `checksum` = `YES` ·
   variant 테이블 **존재**. 하나라도 다르면 거부 판단을 재검토한다.
2. `bin/rails db:migrate:status` 에 예상치 못한 pending 이 없는지 (백업 후).
3. **제3자 발신** 요청에 세미콜론 query 나 선행 대괄호 파라미터가 있는지 접근 로그 확인.
   우리 코드 표면은 위 #3 에서 평면 스칼라임을 실측했으므로, 남은 것은 외부 발신뿐이다.
4. 업로드·다운로드·variant 생성 1회 — **`test/system` 이 0개**라 브라우저·스토리지 통합 경로는
   자동 검증되지 않는다(기준선부터 그렇다).
5. 배포 후 Rails 8.1.4.1 이미지가 실제로 돌는지 + queue/cache/cable DB 연결 + SMTP 1통.

## 남는 공백

- `load_defaults 8.1` 전환은 **별도 작업**이다. `new_framework_defaults_8_1.rb` 7개 항목 전부
  주석 상태이며, 그중 `action_controller.action_on_path_relative_redirect = :raise` 와
  `active_record.raise_on_missing_required_finder_order_columns = true` 는 동작을 바꾼다
  (후자는 8.2 에서 기본값이 되고 현재 동작은 deprecated).
- Active Storage 마이그레이션 3건을 커밋해 이력을 수렴시킬지 여부 — 별도 결정.
  커밋하지 않는 동안 `app:update` 가 매번 다시 복사한다.
- 프로덕션 `report_deprecations = false` 이므로 8.1 의 런타임 deprecation 은 운영에서 안 보인다.
