# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# SafeFile: 검사 대상 문서 본문(text)·이미지(image)는 개인정보를 담고 있으므로 로그에 기록하지 않는다.
Rails.application.config.filter_parameters += [ /\Atext\z/, /\Aimage\z/ ]
