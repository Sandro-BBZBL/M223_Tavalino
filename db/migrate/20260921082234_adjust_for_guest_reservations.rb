class AdjustForGuestReservations < ActiveRecord::Migration[8.1]
  def up
    change_column_null :reservations, :user_id, true
    add_column :reservations, :guest_name, :string
    add_column :reservations, :guest_email, :string
    add_column :reservations, :guest_phone, :string
    add_column :reservations, :confirmation_code, :string
    add_index :reservations, :confirmation_code, unique: true

    change_column_default :users, :role, from: "guest", to: "staff"
    execute "UPDATE users SET role = 'staff' WHERE role = 'guest'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end