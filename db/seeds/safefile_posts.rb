# SafeFile 가이드 정적 글 3개를 블로그 목록에 노출하기 위한 Post 레코드.
# 본문은 public/blog/<slug>/index.html 정적 페이지가 담당한다 —
# /blog/:slug 요청은 정적 파일 핸들러가 posts#show보다 먼저 처리하므로
# 이 레코드는 목록 카드(제목·설명·날짜·카테고리)용으로만 쓰인다.
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

safefile_posts.each do |attrs|
  post = Post.find_or_initialize_by(slug: attrs[:slug])
  post.assign_attributes(
    attrs.merge(
      status: "published",
      published_at: post.published_at || Time.zone.parse("2026-07-16 09:00:00 +09:00")
    )
  )
  post.save!
  puts "Seeded post: #{post.slug} (#{post.status})"
end

puts "SafeFile guide posts: #{Post.where(slug: safefile_posts.map { |p| p[:slug] }).count}/3 present"
