class ApplicationController < ActionController::API
  before_action :authenticate_user!

  attr_reader :current_user

  private

  def authenticate_user!
    token = request.headers["Authorization"]&.split(" ")&.last

    if token.blank?
      return render_error(
        "UNAUTHORIZED",
        "Authorization token is required",
        :unauthorized
      )
    end

    payload = JwtService.decode(token)

    unless payload
      return render_error(
        "UNAUTHORIZED",
        "Invalid or expired token",
        :unauthorized
      )
    end

    @current_user = User.find_by(id: payload["sub"])

    unless @current_user
      render_error(
        "UNAUTHORIZED",
        "User not found",
        :unauthorized
      )
    end
  end

  def render_error(code, message, status)
    render json: {
      error: {
        code: code,
        message: message
      }
    }, status: status
  end

  def serialized_avatar_url(user)
    return nil unless user&.avatar&.attached?

    base_url = URI.parse(ENV.fetch("BACKEND_URL", "http://localhost:3001"))
    Rails.application.routes.url_helpers.rails_blob_url(
      user.avatar,
      host: base_url.host,
      port: base_url.port,
      protocol: base_url.scheme
    )
  end

  def serialized_blob_url(attachment)
    base_url = URI.parse(ENV.fetch("BACKEND_URL", "http://localhost:3001"))
    Rails.application.routes.url_helpers.rails_blob_url(
      attachment,
      host: base_url.host,
      port: base_url.port,
      protocol: base_url.scheme
    )
  end
end
