class CreateInspections < ActiveRecord::Migration[7.1]
  def change
    create_table :inspections do |t|
      # organization_id is denormalized from missions.organization_id (kept
      # in sync in Inspection#set_organization) so every downstream table
      # can be scoped with a single indexed column instead of a join chain.
      t.references :organization, null: false, foreign_key: true
      t.references :mission, null: false, foreign_key: true

      t.string :status, null: false, default: "scheduled" # scheduled | in_progress | completed | archived
      t.datetime :scheduled_at
      t.datetime :completed_at
      t.datetime :archived_at

      t.timestamps
    end

    add_index :inspections, %i[organization_id status]
  end
end
