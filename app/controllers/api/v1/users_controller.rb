class Api::V1::UsersController < ApplicationController
  def index
    users = User.where.not(id: current_user.id)
    search = params[:search].to_s.strip

    if search.present?
      query = "%#{User.sanitize_sql_like(search)}%"
      users = users.where("name ILIKE :query OR email ILIKE :query", query: query)
    end

    render json: {
      items: users.order(:name).limit(50).map do |user|
        {
          id: user.id,
          name: user.name,
          email: user.email,
          avatarUrl: serialized_avatar_url(user)
        }
      end
    }
  end
end
