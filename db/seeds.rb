# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
User.destroy_all
Conversation.destroy_all

kamil = User.create!(
  name: "Kamil",
  email: "kamil@example.com",
  password: "Kamil890",
  password_confirmation: "Kamil890"
)

nadia = User.create!(
  name: "Nadia Putri",
  email: "nadia@example.com",
  password: "Nadia890",
  password_confirmation: "Nadia890"
)

conversation = Conversation.create!(
  kind: "direct"
)

conversation.conversation_participants.create!(
  user: kamil
)

conversation.conversation_participants.create!(
  user: nadia
)

conversation.messages.create!(
  sender: nadia,
  client_message_id: SecureRandom.uuid,
  text: "Halo Kamil!"
)

conversation.messages.create!(
  sender: kamil,
  client_message_id: SecureRandom.uuid,
  text: "Halo Nadia!"
)

puts "Seed selesai."
puts "Kamil: #{kamil.id}"
puts "Nadia: #{nadia.id}"
puts "Conversation: #{conversation.id}"