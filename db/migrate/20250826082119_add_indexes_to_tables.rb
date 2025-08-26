class AddIndexesToTables < ActiveRecord::Migration[7.1]
  def change
    # Note: user_id and conversation_id indexes already exist from references
    # Only add the missing performance indexes for sorting
    
    # Index for sorting conversations by most recent activity
    add_index :conversations, :updated_at
    
    # Index for sorting messages chronologically  
    add_index :messages, :created_at
  end
end