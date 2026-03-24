# Default banners
banners = [
  {
    title_en: "Looking for a teaching job?",
    title_ko: "강사 구직 중이신가요?",
    description_en: "Find the perfect teaching position with TeacherMatch.",
    description_ko: "TeacherMatch에서 완벽한 강사 포지션을 찾아보세요.",
    link_url: "https://teachermatch.kr",
    button_text_en: "Visit TeacherMatch",
    button_text_ko: "TeacherMatch 방문",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 1
  },
  {
    title_en: "Want to learn Korean?",
    title_ko: "한국어 배우고 싶으신가요?",
    description_en: "Start your Korean language journey with HelloKorean.",
    description_ko: "HelloKorean과 함께 한국어 학습을 시작하세요.",
    link_url: "https://hellokorean.org",
    button_text_en: "Start Learning",
    button_text_ko: "학습 시작하기",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 2
  },
  {
    title_en: "Create your own link page",
    title_ko: "나만의 링크 페이지 만들기",
    description_en: "Build a beautiful link-in-bio page in minutes with rolli.",
    description_ko: "rolli로 몇 분 만에 아름다운 링크 페이지를 만드세요.",
    link_url: "https://rolli.ac",
    button_text_en: "Try rolli",
    button_text_ko: "rolli 시작하기",
    position: "after_result",
    page: "all",
    banner_type: "internal",
    sort_order: 3
  }
]

banners.each do |attrs|
  Banner.find_or_create_by!(title_en: attrs[:title_en]) do |b|
    b.assign_attributes(attrs)
  end
end

puts "Seeded #{Banner.count} banners."
