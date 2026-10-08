module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user
    end

    private

    def find_user
      token = request.params[:token]

      reject_unauthorized_connection unless token.present?

      payload = JwtService.decode(token)

      reject_unauthorized_connection unless payload

      user = User.find_by(id: payload["sub"])

      reject_unauthorized_connection unless user

      user
    end
  end
end