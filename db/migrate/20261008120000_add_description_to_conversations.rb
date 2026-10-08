class AddDescriptionToConversations < ActiveRecord::Migration[8.1]
  def change
    add_column :conversations, :description, :text
  end
end
