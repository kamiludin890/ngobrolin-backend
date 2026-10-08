class CreateConversationParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_participants, id: :uuid do |t|
      t.references :conversation,
                   type: :uuid,
                   null: false,
                   foreign_key: true

      t.references :user,
                   type: :uuid,
                   null: false,
                   foreign_key: true

      t.boolean :is_favorite,
                 null: false,
                 default: false

      t.uuid :last_read_message_id

      t.timestamps
    end

    add_index :conversation_participants,
              [:conversation_id, :user_id],
              unique: true,
              name: "index_conversation_participants_unique"

    add_index :conversation_participants,
              :last_read_message_id
  end
end
