BlogStyle.find_or_create_by!(source_name: "기본 전략") do |style|
  style.hooking_patterns = [
    { pattern: "오류/문제 상황 직접 묘사", example: "이메일 전송 버튼을 눌렀는데 '파일이 너무 큽니다' 오류가 떴나요?", when_to_use: "독자가 겪는 구체적 오류 상황을 다룰 때" },
    { pattern: "숫자로 손실 보여주기", example: "공항에서 환전하면 10만원당 최대 3,000원을 더 냅니다", when_to_use: "비교/절약 관련 주제일 때" },
    { pattern: "시간 압박형", example: "마감 30분 전, 파일이 안 보내진다면", when_to_use: "긴급한 상황을 다룰 때" }
  ].to_json

  style.sentence_structure = [
    { feature: "짧은 문장으로 리듬감", example: "파일이 크다. 보내지지 않는다. 마감은 다가온다." },
    { feature: "구체적 상황 묘사로 시작", example: "새벽 2시, 과제 제출 마감 10분 전..." }
  ].to_json

  style.psychological_triggers = [
    { trigger: "손실 회피", description: "얻는 것보다 잃는 것에 더 민감하게 반응", example: "지금 이걸 모르면 계속 손해봅니다" },
    { trigger: "사회적 증거", description: "다른 사람들도 같은 문제를 겪는다는 안도감", example: "하루 2,847명이 이 방법으로 해결했어요" },
    { trigger: "즉각 해결 가능성", description: "복잡하지 않고 바로 해결된다는 확신", example: "30초면 됩니다" }
  ].to_json

  style.tone_style = {
    overall_tone: "친근하지만 신뢰감 있는 전문가 톤",
    key_characteristics: ["구체적 숫자 사용", "독자 상황 공감 먼저", "해결책은 단계별로 명확하게"],
    avoid: ["막연한 표현 (예: 많이, 빠르게, 좋아요)", "과장된 수식어", "수동태 남용"]
  }.to_json

  style.is_active = true
  style.notes = "시스템 기본 전략 — 심리 마케팅 기반 블로그 글쓰기 패턴"
end

puts "BlogStyle seed: 기본 전략 created/found"
