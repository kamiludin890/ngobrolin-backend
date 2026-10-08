class AddHiddenAndClearedAtToConversationParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :conversation_participants, :hidden_at, :datetime
    add_column :conversation_participants, :cleared_at, :datetime
    add_index :conversation_participants, :hidden_at
  end
end
