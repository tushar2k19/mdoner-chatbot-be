class AddStatusToConversations < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:conversations, :status)
      add_column :conversations, :status, :string, default: "active", null: false
      add_index :conversations, :status
    end
  end
end