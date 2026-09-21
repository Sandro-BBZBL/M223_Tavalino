class CreateDiningTables < ActiveRecord::Migration[8.1]
  def change
    create_table :dining_tables do |t|
      t.references :location, null: false, foreign_key: true
      t.integer :number, null: false
      t.integer :capacity, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :dining_tables, [:location_id, :number], unique: true
  end
end
