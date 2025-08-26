class CreateExternalSearchLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :external_search_logs do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :provider
      t.text :query
      t.json :results_json

      t.timestamps
    end
  end
end
