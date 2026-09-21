class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :dining_table, null: false, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :duration_minutes, null: false, default: 120
      t.integer :party_size, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :locked_until

      t.timestamps
    end

    add_index :reservations, [:dining_table_id, :starts_at, :ends_at]
    add_index :reservations, :locked_until
  end
end 