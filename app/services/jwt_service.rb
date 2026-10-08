class JwtService
  ALGORITHM = "HS256"

  def self.encode(user_id)
    payload = {
      sub: user_id,
      exp: 7.days.from_now.to_i
    }

    JWT.encode(
      payload,
      secret,
      ALGORITHM
    )
  end

  def self.decode(token)
    decoded = JWT.decode(
      token,
      secret,
      true,
      algorithm: ALGORITHM
    )

    decoded.first
  rescue JWT::DecodeError,
         JWT::ExpiredSignature,
         JWT::VerificationError
    nil
  end

  def self.secret
    Rails.application.credentials.dig(:jwt, :secret)
  end
end