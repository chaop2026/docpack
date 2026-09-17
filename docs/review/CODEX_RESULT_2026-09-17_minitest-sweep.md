# Codex 교차검증 결과 원문 — minitest 6 × railties 전수 점검

| 항목 | 값 |
|---|---|
| 실행 명령 | `codex exec --sandbox read-only --skip-git-repo-check -C /Users/sunghoon/Projects/docpack -o <결과> - < docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_minitest-sweep.md` |
| 모델 | `gpt-5.5` (provider: openai, reasoning effort: medium) |
| 샌드박스 | `read-only` / approval: never |
| 소요 시간 | **88초** (exit 0) |
| 조각 구성 | **1조각** (분할 없이 한 번에 들어감) |
| 입력 패키지 | `docs/review/CODEX_REVIEW_PACKAGE_2026-09-17_minitest-sweep.md` (비밀값 스캔 0건) |
| 우리 판정 | `docs/review/CROSS_REVIEW_TRIAGE_2026-09-17_minitest-sweep.md` |

⛔아래는 **원문 그대로다. 요약·편집하지 않았다.**

---

판정: **대체로 현재 lock 기준의 즉시 장애 조사는 맞지만, C1/C8은 범위가 과하고 C6은 근거가 부족합니다.** `0 runs` 5건이 “minitest 러너 사망”이라는 위음성일 가능성은 제공 근거 안에서는 낮아 보입니다.

**지적 사항**

1. **논리 오류 / 확신도 높음**  
   **C1의 `minitest >= 6` 표현은 근거보다 넓습니다.**  
   §3-2의 railties 8.0.5.1 코드는 `Minitest::VERSION`을 `when /^5/`, `when /^6/`만 처리합니다. 따라서 근거가 지탱하는 것은 “minitest 6.x는 railties 8.0.5+에서 대응된다”이지, `>= 6` 전체가 아닙니다. minitest 7.x는 어느 분기에도 안 걸릴 수 있다는 §5의 우려 2가 그대로 남습니다.  
   근거: §3-2 `case Minitest::VERSION ... when /^5/ ... when /^6/`; [CLAUDE.md](/Users/sunghoon/Projects/docpack/CLAUDE.md:625)~630.

2. **논리 오류 / 확신도 보통**  
   **C8 “어떤 프로젝트에도 새 minitest 핀이 필요 없다”는 현재 lock 상태로만은 성립하지만, 재해결 drift까지 포함하면 과합니다.**  
   §5의 우려 3처럼 `rails "~> 8.0.4"`는 8.0.4 자체를 허용합니다. 그 프로젝트가 minitest 6을 허용하고 railties가 8.0.4로 재해결되면 §3-1/§3-9의 즉사 조건으로 돌아갑니다. 즉 “현재 죽어 있지 않다”와 “의존성 가드가 불필요하다”는 별개입니다.  
   근거: §3-1, §3-9, §5 우려 3. docpack 자체도 `rails "~> 8.0.4"`와 minitest 5 핀을 함께 둡니다: [Gemfile](/Users/sunghoon/Projects/docpack/Gemfile:74), [Gemfile](/Users/sunghoon/Projects/docpack/Gemfile:80).

3. **논리 오류 / 확신도 보통**  
   **lock 값과 실제 로드 값이 어긋난 사례를 제시했는데, 나머지 프로젝트는 대부분 lock만으로 판정했습니다.**  
   §3-6에서 docpack은 lock이 `5.27.0`인데 실제 로드는 `5.26.2`라고 되어 있습니다. 이 괴리가 생긴 환경이라면, “실제 로드되는 버전도 확인했다”는 문장은 schoolkit/docpack에만 적용되고 나머지 프로젝트의 런타임 판정까지 지탱하지는 못합니다. Bundler 정상 경로라면 lock이 강한 근거이긴 하지만, 이 패키지 자체가 예외를 보여서 방법론상 약점입니다.  
   근거: §3-6 “lock 값이 아니라 실제 로드되는 버전도 확인했다” 블록; [Gemfile.lock](/Users/sunghoon/Projects/docpack/Gemfile.lock:179).

4. **논리 오류 / 확신도 높음**  
   **C6 `pg 1.6.3` segfault가 minitest와 무관하다는 주장은 제공 자료만으로 검증되지 않습니다.**  
   §3-6에는 teachermatch가 `PARALLEL_WORKERS=1`에서 통과했다는 결과만 있고, segfault 로그, 스택, 병렬 8프로세스 실패 출력, minitest/pg 분리 실험이 없습니다. “별건”일 수는 있지만 이 자료만으로는 결론을 확정할 수 없습니다.  
   근거: §3-6 teachermatch 행, §5 C6. 이 검증에는 병렬 segfault 원문 로그가 필요합니다.

**지탱되는 쪽**

C3/C4는 꽤 잘 받쳐집니다. §3-7 canary가 `ActiveSupport::TestCase`를 상속했고, §3-3에 따르면 LineFiltering이 붙는 대상이 그 클래스라서 railties/minitest 충돌 경로를 실제로 탑니다. 따라서 `0 runs` 5건이 “러너가 죽었는데 빈 것처럼 보인 것”이라는 가능성은 낮습니다.

C5도 §3-1과 §3-2의 `MT5#run` 본문이 같아서 실험 목적상 충분히 동등해 보입니다. C7은 §3-9의 `exit 1 + 요약 줄 없음` 재현으로 지탱됩니다.