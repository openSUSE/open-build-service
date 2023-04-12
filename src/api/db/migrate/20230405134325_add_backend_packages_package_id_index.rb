class AddBackendPackagesPackageIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :backend_packages, %w[package_id], name: :index_backend_packages_package_id, unique: true
  end
end
