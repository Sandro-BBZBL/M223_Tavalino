# Projektantrag v2 (Feedback 21.09.2026): Die 5-Minuten-Sperre entfällt.
# Statt locked_until gibt es lock_version (Optimistic Locking), der Status
# kennt nur noch "confirmed" und "cancelled".
class SwitchReservationsToOptimisticLocking < ActiveRecord::Migration[8.1]
  def up
    remove_index :reservations, :locked_until
    remove_column :reservations, :locked_until

    add_column :reservations, :lock_version, :integer, null: false, default: 0

    execute "UPDATE reservations SET status = 'confirmed' WHERE status = 'pending'"
    change_column_default :reservations, :status, from: "pending", to: "confirmed"
  end

  def down
    change_column_default :reservations, :status, from: "confirmed", to: "pending"
    remove_column :reservations, :lock_version

    add_column :reservations, :locked_until, :datetime
    add_index :reservations, :locked_until
  end
end