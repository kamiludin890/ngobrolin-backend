require "test_helper"

class Api::V1::ChatManagementTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      name: "Current User",
      email: "current@example.test",
      password: "password123",
      password_confirmation: "password123"
    )
    @contact = User.create!(
      name: "Contact Person",
      email: "contact@example.test",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "contact search excludes the authenticated user" do
    get "/api/v1/users",
        params: { search: "contact@example.test" },
        headers: auth_headers

    assert_response :success
    assert_equal [ @contact.id ], response.parsed_body.fetch("items").map { |user| user.fetch("id") }
  end

  test "profile update persists the current user's name and email" do
    patch "/api/v1/auth/profile",
          params: { name: "Updated User", email: "updated@example.test" },
          headers: auth_headers,
          as: :json

    assert_response :success
    assert_equal "Updated User", @user.reload.name
    assert_equal "updated@example.test", @user.email
  end

  test "creating a direct conversation persists both participants and reuses it" do
    request_params = { kind: "direct", participantIds: [ @contact.id ] }

    post "/api/v1/conversations", params: request_params, headers: auth_headers, as: :json

    assert_response :created
    conversation_id = response.parsed_body.fetch("id")
    conversation = Conversation.find(conversation_id)
    assert_equal [ @user.id, @contact.id ].sort, conversation.participants.pluck(:id).sort

    post "/api/v1/conversations", params: request_params, headers: auth_headers, as: :json

    assert_response :success
    assert_equal conversation_id, response.parsed_body.fetch("id")
    assert_equal 1, Conversation.where(kind: "direct").count
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{JwtService.encode(@user.id)}" }
  end
end
