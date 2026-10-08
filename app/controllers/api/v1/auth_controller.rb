class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!,
                     only: [ :register, :login ]

  def register
    user = User.new(user_params)

    if user.save
      token = JwtService.encode(user.id)

      render json: {
        user: serialize_user(user),
        accessToken: token
      }, status: :created
    else
      render json: {
        error: {
          code: "VALIDATION_ERROR",
          message: user.errors.full_messages.join(", ")
        }
      }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(
      email: params[:email].to_s.strip.downcase
    )

    unless user&.authenticate(params[:password])
      return render json: {
        error: {
          code: "INVALID_CREDENTIALS",
          message: "Email atau password salah"
        }
      }, status: :unauthorized
    end

    token = JwtService.encode(user.id)

    render json: {
      user: serialize_user(user),
      accessToken: token
    }
  end

  def me
    render json: {
      user: serialize_user(current_user)
    }
  end

  def update_profile
    if current_user.update(profile_params)
      render json: {
        user: serialize_user(current_user)
      }
    else
      render json: {
        error: {
          code: "VALIDATION_ERROR",
          message: current_user.errors.full_messages.join(", ")
        }
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(
      :name,
      :email,
      :password,
      :password_confirmation
    )
  end

  def profile_params
    params.permit(:name, :email)
  end

  def serialize_user(user)
    {
      id: user.id,
      name: user.name,
      email: user.email
    }
  end
end
