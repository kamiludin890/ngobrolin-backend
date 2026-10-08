class CreateConversations < ActiveRecord::Migration[8.1]
   def change
    create_table :conversations, id: :uuid do |t|
      t.string :kind, null: false, default: "direct"
      t.string :title
      t.string :avatar_url

      t.timestamps
    end

    add_index :conversations, :kind
  end
end
