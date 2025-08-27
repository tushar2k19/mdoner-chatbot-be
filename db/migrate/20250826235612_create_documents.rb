class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.string :original_filename, null: false
      t.string :s3_key, null: false, limit: 500
      t.string :s3_bucket, null: false, limit: 100
      t.string :s3_url, limit: 1000
      t.string :s3_region, limit: 50, default: 'us-east-1'
      t.string :status, limit: 20, default: 'inactive', null: false
      t.bigint :file_size, null: false
      t.string :mime_type, limit: 100, default: 'application/pdf'
      t.string :openai_file_id, limit: 255
      t.string :openai_vector_store_id, limit: 255
      t.string :sha256_hash, limit: 64

      t.timestamps
    end

    # Add indexes for performance
    add_index :documents, :status
    add_index :documents, :openai_file_id, unique: true
    add_index :documents, :original_filename
    add_index :documents, :s3_key
  end
end
