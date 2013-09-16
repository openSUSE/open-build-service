require 'backend_package'

class CreateBackendPackage < ActiveRecord::Migration

  def change
    create_table :backend_packages, id: false do |t|
      t.belongs_to :package, null: false
      t.primary_key :package_id
      t.belongs_to :links_to
      t.datetime :updated_at
      t.string :srcmd5
      t.string :changesmd5
      t.string :verifymd5
      t.string :expandedmd5
      t.string :error
      t.datetime :maxmtime
    end
    add_index :backend_packages, :links_to_id

    drop_table :linked_packages

    UpdatePackageMetaJob.new.delay.perform
  end
end
