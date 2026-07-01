class CreateMissions < ActiveRecord::Migration[7.1]
  def change
    create_table :missions do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "scheduled" # scheduled | in_progress | completed | archived
      t.datetime :archived_at

      t.timestamps
    end

    add_index :missions, %i[organization_id status]
  end
end
