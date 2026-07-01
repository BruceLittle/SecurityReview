class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :inspection, null: false, foreign_key: true

      t.string :asset_type, null: false # e.g. roof, drone_flight, structure
      t.string :identifier, null: false

      t.timestamps
    end

    add_index :assets, %i[organization_id inspection_id]
  end
end
