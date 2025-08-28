class CreateConversations < ActiveRecord::Migration[7.1]
  def change
    create_table :conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, limit: 255
      t.string :openai_thread_id, null: false, limit: 255
      t.string :status, limit: 20, default: 'active', null: false

      t.timestamps
    end

    # Add indexes for performance
    add_index :conversations, :openai_thread_id, unique: true
    add_index :conversations, :status
    add_index :conversations, :updated_at
  end
end
