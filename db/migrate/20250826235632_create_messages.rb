class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, limit: 20, null: false
      t.text :content, null: false
      t.string :source, limit: 10, default: 'dpr', null: false
      t.string :openai_message_id, limit: 255
      t.string :openai_run_id, limit: 255

      t.timestamps
    end

    # Add indexes for performance
    add_index :messages, :role
    add_index :messages, :source
    add_index :messages, :created_at
    add_index :messages, :openai_message_id
    add_index :messages, :openai_run_id
  end
end
