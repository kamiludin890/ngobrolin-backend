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
end