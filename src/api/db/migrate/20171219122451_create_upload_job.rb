class CreateUploadJob < ActiveRecord::Migration[5.1]
  def change
    create_table :cloud_user_upload_jobs, id: :integer do |t|
      t.belongs_to :user, index: true, type: :integer
      t.integer :job_id

      t.timestamps
    end
    add_index :cloud_user_upload_jobs, :job_id, unique: true
  end
end
