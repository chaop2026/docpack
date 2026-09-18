# Codex 결과 원문 — 젬 업그레이드 (2026-09-18)

- codex-cli 0.144.3, `codex exec --sandbox read-only`
- 패키지: `docs/review/CODEX_REVIEW_PACKAGE_2026-09-18_gems.md`
- tokens used: 55,004
- ⚠️ Codex 는 read-only 샌드박스에서 **저장소를 직접 읽었다**(패키지 밖 파일 포함 — `rg`/`sed` 로 Gemfile.lock·서비스 파일 등). 줄 번호 인용은 그 실제 파일 기준이다.

---

**검토 결과**

지적은 3건입니다. 모두 이번 저장소의 반복 실패 유형인 “조용한 실패 / 공허한 검사” 쪽입니다.

1. **논리 오류, 확신도 높음** — `script/canonical_sweep.rb` 는 sitemap 자체가 깨져도 빈 `SLUGS` 로 통과할 수 있습니다.  
   근거: [script/canonical_sweep.rb:83](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:83)-85 에서 `/sitemap.xml` 응답 코드나 `<loc>` 개수를 단언하지 않고 body 만 파싱합니다. 이후 [144](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:144), [159](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:159) 는 `SLUGS.each` 라서 0회 실행될 수 있고, [154](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:154), [172](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:172) 는 숫자만 출력합니다. sitemap 500/빈 XML/파싱 실패가 “0 entries checked”로 끝나는 형태입니다.

2. **논리 오류, 확신도 높음** — `[5/6]` JSON-LD 검사는 실제 JSON-LD 단언 수가 0이어도 성공합니다.  
   근거: [script/canonical_sweep.rb:182](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:182)-192 는 JSON-LD block 안의 `"url"`/`"@id"` 중 `u.include?("/blog/")` 인 값만 검사합니다. JSON-LD block 이 없거나, blog URL 필드가 없어지거나, URL 형태가 필터에 안 걸리면 실패가 없습니다. [204](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:204) 의 “pages checked”는 페이지 수이지 JSON-LD 비교 수가 아닙니다.

3. **배포 위험, 확신도 보통** — `middleware_probe.sh` 의 임시 initializer 는 SIGKILL/컨테이너 강제 종료 시 남을 수 있고, 남으면 이후 production boot 에서 정적 파일 서빙을 계속 끕니다.  
   근거: [script/middleware_probe.sh:14](/Users/sunghoon/Projects/docpack/script/middleware_probe.sh:14)-16 이 `config/initializers/aaa_static_probe.rb` 를 `trap EXIT` 로만 지우고, [30](/Users/sunghoon/Projects/docpack/script/middleware_probe.sh:30) 이 production initializer 로 `public_file_server.enabled = false` 를 씁니다. `trap EXIT` 는 SIGKILL 을 처리하지 못합니다. 다만 이 스크립트가 일회성 컨테이너/깨끗한 worktree 에서만 실행된다면 위험도는 내려갑니다.

**질문별 답**

Q1. `rails "~> 8.0.5"` 로 충분합니다. [Gemfile:11](/Users/sunghoon/Projects/docpack/Gemfile:11) 이 rails 를 `>= 8.0.5, < 8.1` 로 제한하고, lock 상 rails 는 railties 를 정확히 같은 버전으로 요구합니다: `rails (8.0.5.1)` 아래 `railties (= 8.0.5.1)`. 다른 항목들은 `railties >= ...` 하한만 있으므로 이 번들에서 railties 만 8.0.5 미만으로 내려갈 실제 경로는 보이지 않습니다.

Q2. `minitest "< 7"` 은 현재로서는 맞는 안전장치입니다. [Gemfile:92](/Users/sunghoon/Projects/docpack/Gemfile:92). 다만 “상한만” 두면 나중에 railties 가 고쳐져도 남을 수 있으니, 줄 필터링이 실제로 1개 테스트만 실행하는지 CI 단언을 추가하는 쪽이 더 좋은 보완입니다. 알려진 `VERSION = "5.26.2"` 오기는 gem resolver 의 `< 7` 판정 자체를 무력화하지는 않습니다.

Q3. `minitest-mock` 추가는 합리적입니다. [Gemfile:99](/Users/sunghoon/Projects/docpack/Gemfile:99). 두 테스트가 `require "minitest/mock"` 에 의존한다는 전제라면, 직접 `Object#stub` 을 재구현하는 쪽이 더 위험합니다. 단, 테스트 표면이 작다면 장기적으로는 mock/stub 의존을 걷어내는 리팩터는 가능해 보입니다.

Q4. puma 8 보류는 과하지 않습니다. [config/puma.rb:31](/Users/sunghoon/Projects/docpack/config/puma.rb:31) 이 host 없는 `port` 이고, [Dockerfile:84](/Users/sunghoon/Projects/docpack/Dockerfile:84) 는 production 에서 rails server 를 그대로 띄웁니다. `proxy.app_port` 는 프록시가 어디로 붙을지의 문제이지 Puma 의 bind host 를 고정하지 않습니다. puma 8 로 올릴 거면 `port ENV.fetch("PORT", 3001), "0.0.0.0"` 같은 명시가 먼저입니다.

Q5. 보류가 “도달 가능한 알려진 보안 취약점 방치”로는 보이지 않습니다. 호출부는 `ImageProcessing::Vips.source(...).resize/convert/saver(...).call` 형태이고 [image_compressor.rb:37](/Users/sunghoon/Projects/docpack/app/services/image_compressor.rb:37)-39, [social_resizer.rb:20](/Users/sunghoon/Projects/docpack/app/services/social_resizer.rb:20)-25, [pdf_builder.rb:31](/Users/sunghoon/Projects/docpack/app/services/pdf_builder.rb:31)-35 에서 loader/saver option 을 사용자 입력으로 넘기거나 `#apply` 를 쓰는 경로가 보이지 않습니다.

Q6. 위 1, 2번이 실제 공허 검사입니다. `[1/6]` 의 `allowed_200` 은 [script/canonical_sweep.rb:137](/Users/sunghoon/Projects/docpack/script/canonical_sweep.rb:137) 기준으로는 너무 넓다고 보진 않습니다.

Q7. initializer 순서 전제는 이 패키지 설명 안에서는 타당합니다. 위험은 순서보다 잔존 파일입니다.

Q8. workflow trigger 는 `pull_request` 와 `push` 뿐입니다. [ci.yml:3](/Users/sunghoon/Projects/docpack/.github/workflows/ci.yml:3)-6. `pull_request_target`/`workflow_run` 은 없습니다. checkout v7 판단은 안전해 보입니다.

Q9. (a)급으로 보이는 건 `canonical_sweep.rb` 의 sitemap/JSON-LD 공허 검사입니다. `public/privacy/index.html` 링크 수정과 Ruby 3.3.9 정렬은 분리하면 더 깨끗했겠지만, 이 패키지만으로 배포 차단급 결함은 아닙니다.
