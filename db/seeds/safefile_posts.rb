# SafeFile 가이드 글 3개의 Post 레코드.
#
# ⚠️ 이 시드는 **`blog:migrate_privacy` 로 대체됐다.** 원래 전제는 위 주석에 있던
# "본문은 `public/blog/<slug>/index.html` 정적 페이지가 담당한다" 였고, 그래서
# 본문 없는 published 레코드를 만드는 것이 의도였다. 그 전제는 두 번 깨졌다:
#
#   1. `9f8bfff`(2026-07-17)가 `public/blog/` 를 삭제했다 — 본문을 담당할 정적
#      파일이 더는 없다. `blog:migrate_privacy` 가 `db/blog_privacy/*.html` 를
#      DB 로 옮기면서 슬러그도 서술형으로 **개명**했다
#      (`rrn-masking` → `resident-number-masking`,
#       `contract-checklist` → `contract-sharing-checklist`).
#      아래 슬러그는 개명 **전** 값이라, 마이그레이션이 끝난 DB 에서 이 시드를
#      돌리면 기존 글을 찾지 못하고 **본문 없는 중복 글을 새로 만든다.**
#   2. 2026-09-18 의 `validates :body_ko, if: published` 가 그 생성을 거부한다.
#      즉 지금 이 시드는 신선한 DB 에서도 완주하지 못한다 (실측: 두 번째 항목에서
#      `RecordInvalid` 로 중단).
#
# 검증이 이 시드의 버그를 **잡아준 것**이다 — 검증 전에는 조용히 본문 없는 published
# 중복 2개를 만들어 /blog 목록과 사이트맵을 오염시켰다.
#
# 아래 루프는 그래도 항목 단위로 격리한다(같은 커밋에서 잡·레이크 전체에 적용한
# 규칙). 한 항목의 실패가 다른 항목을 막지 않고, 실패는 조용히 지나가지 않는다.
# **이 파일을 어떻게 정리할지(마이그레이션에 합치기 / 본문을 `db/blog_privacy/`
# 에서 읽게 하기 / 삭제)는 별도 결정이라 이번 커밋에서 손대지 않았다.**
safefile_posts = [
  {
    slug: "resume-privacy",
    title_ko: "이력서 속 개인정보, 어디까지 써야 할까",
    title_en: "Personal Info on Your Resume: How Much Is Too Much?",
    category: "student",
    meta_description_ko: "이력서에 주민등록번호, 집 주소, 생년월일까지 다 써야 할까요? 채용에 꼭 필요한 정보와 지워도 되는 개인정보 7가지, 그리고 안전하게 가리는 방법을 정리했습니다.",
    meta_description_en: "Do you really need your ID number, home address, and birth date on a resume? 7 pieces of personal info you can safely remove — and how to redact them."
  },
  {
    slug: "rrn-masking",
    title_ko: "주민등록번호 마스킹, 뒷자리만 가리면 될까",
    title_en: "Masking Korean ID Numbers: Is Hiding the Back Digits Enough?",
    category: "office",
    meta_description_ko: "주민등록번호 뒷자리에는 어떤 정보가 들어 있을까요? 서류 제출 전 주민번호를 올바르게 마스킹하는 방법과 등본·신분증 사본 제출 시 주의사항을 정리했습니다.",
    meta_description_en: "What's actually encoded in a Korean RRN? How to mask resident registration numbers correctly before submitting documents or ID copies."
  },
  {
    slug: "contract-checklist",
    title_ko: "계약서·서류를 보내기 전, 8가지 체크리스트",
    title_en: "8-Point Privacy Checklist Before Sharing Contracts & Documents",
    category: "freelancer",
    meta_description_ko: "부동산 계약서, 프리랜서 계약서, 급여명세서를 카톡이나 메일로 보내기 전에 확인해야 할 개인정보 체크리스트. 계좌번호, 도장, 서명까지 놓치기 쉬운 항목을 정리했습니다.",
    meta_description_en: "A privacy checklist for sharing lease contracts, freelance agreements, and pay stubs — account numbers, stamps, and signatures people forget to redact."
  }
]

seeded = 0
rejected = []

safefile_posts.each do |attrs|
  post = Post.find_or_initialize_by(slug: attrs[:slug])
  post.assign_attributes(
    attrs.merge(
      status: "published",
      published_at: post.published_at || Time.zone.parse("2026-07-16 09:00:00 +09:00")
    )
  )

  begin
    post.save!
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    rejected << [ attrs[:slug], e.message ]
    warn "  ! #{attrs[:slug]} rejected — #{e.message} — skipping"
    next
  end

  seeded += 1
  puts "Seeded post: #{post.slug} (#{post.status})"
end

puts "SafeFile guide posts: #{Post.where(slug: safefile_posts.map { |p| p[:slug] }).count}/3 present"

if rejected.any?
  # Loud on purpose, and non-zero on purpose. Isolating the bad item keeps the
  # others going, but this task is on the post-deploy command list (CLAUDE.md),
  # where a run that seeds nothing and exits 0 reads as success. So: every item
  # gets its turn, then the task fails.
  warn "\n#{rejected.size}/#{safefile_posts.size} rejected — this seed is superseded by " \
       "blog:migrate_privacy (see the header comment). Seeded #{seeded}."
  rejected.each { |slug, message| warn "  #{slug}: #{message}" }
  abort "blog:seed_safefile_posts: #{rejected.size} post(s) could not be seeded"
end
