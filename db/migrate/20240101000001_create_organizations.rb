class CreateOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :status, null: false, default: "active" # active | suspended

      t.timestamps
    end

    add_index :organizations, :slug, unique: true
  end
end
