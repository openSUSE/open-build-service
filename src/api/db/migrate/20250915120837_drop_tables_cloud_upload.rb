class DropTablesCloudUpload < ActiveRecord::Migration[7.2]
  def change
    drop_table 'cloud_azure_configurations', id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'user_id'
      t.text 'application_id'
      t.text 'application_key'
      t.datetime 'created_at', precision: nil, null: false
      t.datetime 'updated_at', precision: nil, null: false
      t.index ['user_id'], name: 'index_cloud_azure_configurations_on_user_id'
    end

    drop_table 'cloud_ec2_configurations', id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'user_id'
      t.string 'external_id'
      t.string 'arn'
      t.datetime 'created_at', precision: nil, null: false
      t.datetime 'updated_at', precision: nil, null: false
      t.index %w[external_id arn], name: 'index_cloud_ec2_configurations_on_external_id_and_arn', unique: true
      t.index ['user_id'], name: 'index_cloud_ec2_configurations_on_user_id'
    end

    drop_table 'cloud_user_upload_jobs', id: :integer, charset: 'utf8mb4', collation: 'utf8mb4_unicode_ci', options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC', force: :cascade do |t|
      t.integer 'user_id'
      t.integer 'job_id'
      t.datetime 'created_at', precision: nil, null: false
      t.datetime 'updated_at', precision: nil, null: false
      t.index ['job_id'], name: 'index_cloud_user_upload_jobs_on_job_id', unique: true
      t.index ['user_id'], name: 'index_cloud_user_upload_jobs_on_user_id'
    end
  end
end
