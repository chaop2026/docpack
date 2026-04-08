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

ActiveRecord::Schema[8.0].define(version: 2026_04_08_071252) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "banners", force: :cascade do |t|
    t.string "title_en", default: "", null: false
    t.string "title_ko", default: "", null: false
    t.string "description_en", default: ""
    t.string "description_ko", default: ""
    t.string "link_url"
    t.string "button_text_en", default: "Learn More"
    t.string "button_text_ko", default: "자세히 보기"
    t.string "image_url"
    t.string "position", default: "after_result", null: false
    t.string "page", default: "all", null: false
    t.boolean "active", default: true, null: false
    t.integer "sort_order", default: 0, null: false
    t.string "banner_type", default: "internal", null: false
    t.string "adsense_slot_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["page", "position", "active", "sort_order"], name: "index_banners_on_page_position_active_sort"
  end

  create_table "blog_styles", force: :cascade do |t|
    t.string "source_name"
    t.text "raw_script"
    t.text "hooking_patterns"
    t.text "sentence_structure"
    t.text "psychological_triggers"
    t.text "tone_style"
    t.boolean "is_active", default: true
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "blog_topics", force: :cascade do |t|
    t.string "topic"
    t.string "category"
    t.boolean "used", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "conversions", force: :cascade do |t|
    t.string "conversion_type"
    t.string "status"
    t.integer "original_size"
    t.integer "result_size"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.string "title_ko"
    t.string "title_en"
    t.text "body_ko"
    t.text "body_en"
    t.string "slug"
    t.string "category"
    t.string "status"
    t.datetime "published_at"
    t.text "cover_svg"
    t.string "meta_description_ko"
    t.string "meta_description_en"
    t.integer "view_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trust_bar"
    t.string "pain_tag"
    t.text "error_mockup"
    t.text "recognition_text"
    t.text "loss_items"
    t.text "stats"
    t.string "subtitle_ko"
    t.index ["slug"], name: "index_posts_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
end
