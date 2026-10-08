require "test_helper"
require "base64"

class Api::V1::ChatManagementTest < ActionDispatch::IntegrationTest
  include ActionCable::TestHelper

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

  test "profile update attaches an image and returns its URL" do
    Tempfile.create([ "avatar", ".png" ]) do |file|
      file.binmode
      file.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="))
      file.flush

      image = Rack::Test::UploadedFile.new(file.path, "image/png", true)
      patch "/api/v1/auth/profile",
            params: { avatar: image },
            headers: auth_headers
    end

    assert_response :success
    assert @user.reload.avatar.attached?
    assert_match %r{\Ahttp://localhost:3001/rails/active_storage/}, response.parsed_body.dig("user", "avatarUrl")
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

  test "creating a message broadcasts it to the conversation stream" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")

    assert_broadcasts("conversation_#{conversation_id}", 1) do
      post "/api/v1/conversations/#{conversation_id}/messages",
           params: { clientMessageId: "message-1", text: "Realtime test" },
           headers: auth_headers,
           as: :json
    end

    assert_response :created
  end

  test "deleting a conversation hides it only for the current participant" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")

    delete "/api/v1/conversations/#{conversation_id}", headers: auth_headers
    assert_response :no_content

    get "/api/v1/conversations", headers: auth_headers
    assert_empty response.parsed_body.fetch("items")

    get "/api/v1/conversations",
        headers: { "Authorization" => "Bearer #{JwtService.encode(@contact.id)}" }
    assert_equal [ conversation_id ], response.parsed_body.fetch("items").map { |item| item.fetch("id") }
  end

  test "a new incoming message restores a conversation hidden by the current user" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")
    delete "/api/v1/conversations/#{conversation_id}", headers: auth_headers

    post "/api/v1/conversations/#{conversation_id}/messages",
         params: { clientMessageId: "new-after-hide", text: "I am back" },
         headers: { "Authorization" => "Bearer #{JwtService.encode(@contact.id)}" },
         as: :json

    get "/api/v1/conversations", headers: auth_headers
    assert_equal [ conversation_id ], response.parsed_body.fetch("items").map { |item| item.fetch("id") }
  end

  test "clearing messages hides old history only for the current participant" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")
    post "/api/v1/conversations/#{conversation_id}/messages",
         params: { clientMessageId: "before-clear", text: "Old message" },
         headers: auth_headers,
         as: :json

    delete "/api/v1/conversations/#{conversation_id}/messages", headers: auth_headers
    assert_response :no_content

    get "/api/v1/conversations/#{conversation_id}/messages", headers: auth_headers
    assert_empty response.parsed_body.fetch("items")

    get "/api/v1/conversations/#{conversation_id}/messages",
        headers: { "Authorization" => "Bearer #{JwtService.encode(@contact.id)}" }
    assert_equal [ "Old message" ], response.parsed_body.fetch("items").map { |item| item.fetch("text") }

    post "/api/v1/conversations/#{conversation_id}/messages",
       params: { clientMessageId: "after-clear", text: "New message" },
       headers: { "Authorization" => "Bearer #{JwtService.encode(@contact.id)}" },
       as: :json
    get "/api/v1/conversations", headers: auth_headers
    assert_equal 1, response.parsed_body.fetch("items").first.fetch("unreadCount")
  end

  test "message attachments are persisted and serialized for preview" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")

    Tempfile.create([ "message-image", ".png" ]) do |file|
      file.binmode
      file.write(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="))
      file.flush
      image = Rack::Test::UploadedFile.new(file.path, "image/png", true)

      post "/api/v1/conversations/#{conversation_id}/messages",
           params: { clientMessageId: "image-message", text: "", attachments: [ image ] },
           headers: auth_headers
    end

    assert_response :created
    attachment = response.parsed_body.fetch("attachments").first
    assert_equal "image/png", attachment.fetch("contentType")
    assert_match %r{\Ahttp://localhost:3001/rails/active_storage/}, attachment.fetch("url")
    assert Message.find(response.parsed_body.fetch("id")).attachments.attached?
  end

  test "message search only returns matching messages in the conversation" do
    post "/api/v1/conversations",
         params: { kind: "direct", participantIds: [ @contact.id ] },
         headers: auth_headers,
         as: :json
    conversation_id = response.parsed_body.fetch("id")
    [ [ "search-1", "Find this needle" ], [ "search-2", "Nothing here" ] ].each do |client_id, text|
      post "/api/v1/conversations/#{conversation_id}/messages",
           params: { clientMessageId: client_id, text: text },
           headers: auth_headers,
           as: :json
    end

    get "/api/v1/conversations/#{conversation_id}/messages",
        params: { search: "needle" },
        headers: auth_headers

    assert_response :success
    assert_equal [ "Find this needle" ], response.parsed_body.fetch("items").map { |item| item.fetch("text") }
  end

  private

  def auth_headers
    { "Authorization" => "Bearer #{JwtService.encode(@user.id)}" }
  end
end
