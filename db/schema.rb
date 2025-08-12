# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_07_13_161719) do
  create_table "action_nodes", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "task_version_id", null: false
    t.bigint "parent_id"
    t.text "content", null: false
    t.datetime "review_date"
    t.integer "level", default: 1
    t.string "list_style", default: "decimal"
    t.boolean "completed", default: false
    t.integer "position", null: false
    t.string "node_type", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "reviewer_id"
    t.index ["deleted_at"], name: "index_action_nodes_on_deleted_at"
    t.index ["parent_id"], name: "index_action_nodes_on_parent_id"
    t.index ["reviewer_id"], name: "index_action_nodes_on_reviewer_id"
    t.index ["task_version_id"], name: "index_action_nodes_on_task_version_id"
  end

  create_table "comment_trails", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "review_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_comment_trails_on_deleted_at"
    t.index ["review_id"], name: "index_comment_trails_on_review_id"
  end

  create_table "comments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "review_date", null: false
    t.bigint "user_id", null: false
    t.bigint "comment_trail_id", null: false
    t.bigint "action_node_id"
    t.boolean "resolved", default: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action_node_id"], name: "index_comments_on_action_node_id"
    t.index ["comment_trail_id"], name: "index_comments_on_comment_trail_id"
    t.index ["deleted_at"], name: "index_comments_on_deleted_at"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "notifications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.bigint "task_id", null: false
    t.bigint "review_id"
    t.string "message", null: false
    t.boolean "read", default: false
    t.string "notification_type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_notifications_on_deleted_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["review_id"], name: "index_notifications_on_review_id"
    t.index ["task_id"], name: "index_notifications_on_task_id"
  end

  create_table "reviews", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "task_version_id", null: false
    t.bigint "base_version_id"
    t.bigint "reviewer_id"
    t.string "status", default: "pending", null: false
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["base_version_id"], name: "index_reviews_on_base_version_id"
    t.index ["deleted_at"], name: "index_reviews_on_deleted_at"
    t.index ["reviewer_id"], name: "index_reviews_on_reviewer_id"
    t.index ["task_version_id"], name: "index_reviews_on_task_version_id"
  end

  create_table "task_versions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "editor_id"
    t.bigint "base_version_id"
    t.integer "version_number", null: false
    t.string "status", default: "draft", null: false
    t.text "change_description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["base_version_id"], name: "index_task_versions_on_base_version_id"
    t.index ["deleted_at"], name: "index_task_versions_on_deleted_at"
    t.index ["editor_id"], name: "index_task_versions_on_editor_id"
    t.index ["task_id"], name: "index_task_versions_on_task_id"
  end

  create_table "tasks", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "sector_division", null: false
    t.text "description", null: false
    t.datetime "original_date", null: false
    t.string "responsibility", null: false
    t.datetime "review_date", null: false
    t.datetime "completed_at"
    t.integer "status", default: 0
    t.bigint "editor_id"
    t.bigint "reviewer_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "current_version_id"
    t.index ["current_version_id"], name: "index_tasks_on_current_version_id"
    t.index ["deleted_at"], name: "index_tasks_on_deleted_at"
    t.index ["editor_id"], name: "index_tasks_on_editor_id"
    t.index ["reviewer_id"], name: "index_tasks_on_reviewer_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name"
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "action_nodes", "action_nodes", column: "parent_id"
  add_foreign_key "action_nodes", "task_versions"
  add_foreign_key "comment_trails", "reviews"
  add_foreign_key "comments", "action_nodes", on_delete: :nullify
  add_foreign_key "comments", "comment_trails"
  add_foreign_key "comments", "users"
  add_foreign_key "notifications", "reviews"
  add_foreign_key "notifications", "tasks"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "reviews", "task_versions"
  add_foreign_key "reviews", "task_versions", column: "base_version_id"
  add_foreign_key "reviews", "users", column: "reviewer_id"
  add_foreign_key "task_versions", "task_versions", column: "base_version_id"
  add_foreign_key "task_versions", "tasks"
  add_foreign_key "task_versions", "users", column: "editor_id"
  add_foreign_key "tasks", "task_versions", column: "current_version_id"
  add_foreign_key "tasks", "users", column: "editor_id"
  add_foreign_key "tasks", "users", column: "reviewer_id"
end
