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

ActiveRecord::Schema[8.1].define(version: 2026_09_21_082234) do
  create_table "dining_tables", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "capacity", null: false
    t.datetime "created_at", null: false
    t.integer "location_id", null: false
    t.integer "number", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id", "number"], name: "index_dining_tables_on_location_id_and_number", unique: true
    t.index ["location_id"], name: "index_dining_tables_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "reservations", force: :cascade do |t|
    t.string "confirmation_code"
    t.datetime "created_at", null: false
    t.integer "dining_table_id", null: false
    t.integer "duration_minutes", default: 120, null: false
    t.datetime "ends_at", null: false
    t.string "guest_email"
    t.string "guest_name"
    t.string "guest_phone"
    t.datetime "locked_until"
    t.integer "party_size", null: false
    t.datetime "starts_at", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["confirmation_code"], name: "index_reservations_on_confirmation_code", unique: true
    t.index ["dining_table_id", "starts_at", "ends_at"], name: "idx_on_dining_table_id_starts_at_ends_at_1f8a494048"
    t.index ["dining_table_id"], name: "index_reservations_on_dining_table_id"
    t.index ["locked_until"], name: "index_reservations_on_locked_until"
    t.index ["user_id"], name: "index_reservations_on_user_id"
  end

  create_table "user_locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "location_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["location_id"], name: "index_user_locations_on_location_id"
    t.index ["user_id", "location_id"], name: "index_user_locations_on_user_id_and_location_id", unique: true
    t.index ["user_id"], name: "index_user_locations_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "role", default: "staff", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "dining_tables", "locations"
  add_foreign_key "reservations", "dining_tables"
  add_foreign_key "reservations", "users"
  add_foreign_key "user_locations", "locations"
  add_foreign_key "user_locations", "users"
end
