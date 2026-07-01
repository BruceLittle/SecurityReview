class CreateAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :attachments do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :asset, null: false, foreign_key: true
      t.references :uploaded_by_user, null: true, foreign_key: { to_table: :users }

      # Server-generated (SecureRandom.uuid), never derived from client input,
      # so an S3 key can't be guessed or walked. See Attachment#set_s3_key.
      t.string :s3_key, null: false
      t.string :content_type, null: false
      t.bigint :byte_size

      t.string :status, null: false, default: "pending" # pending | processed | quarantined
      t.string :external_reference_id # correlates with the vendor scan webhook

      t.datetime :archived_at
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :attachments, :s3_key, unique: true
    add_index :attachments, :external_reference_id, unique: true
    add_index :attachments, %i[organization_id asset_id]
    add_index :attachments, :deleted_at
  end
end
