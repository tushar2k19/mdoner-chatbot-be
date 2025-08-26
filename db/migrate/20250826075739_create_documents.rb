class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.string :original_filename
      t.string :openai_file_id
      t.string :vector_store_id
      t.integer :file_size
      t.string :sha256_hash
      t.string :ocr_status

      t.timestamps
    end
  end
end
