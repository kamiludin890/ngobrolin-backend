class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages, id: :uuid do |t|
      t.references :conversation,
                   type: :uuid,
                   null: false,
                   foreign_key: true

      t.references :sender,
                   type: :uuid,
                   null: false,
                   foreign_key: {
                     to_table: :users
                   }

      t.text :text,
              null: false

      t.string :client_message_id,
               null: false

      t.timestamps
    end

    add_index :messages,
              [:conversation_id, :client_message_id],
              unique: true,
              name: "index_messages_idempotency"
  end
end
