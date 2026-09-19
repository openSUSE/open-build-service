class IndexDistrosOnVendorIdAndName < ActiveRecord::Migration[8.1]
  def up
    if foreign_key_exists?(:distros, :vendors)
      remove_foreign_key :distros, :vendors
    end
    remove_index :distros, name: 'index_distros_on_vendor_id', column: 'vendor_id'

    add_index :distros, %w[vendor_id name], name: 'index_distros_on_vendor_id_and_name', unique: true
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :distros, :vendors
    ensure
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end

  def down
    remove_foreign_key :distros, :vendors
    remove_index :distros, name: 'index_distros_on_vendor_id_and_name'

    add_index :distros, ['vendor_id'], name: 'index_distros_on_vendor_id', unique: true
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :distros, :vendors
    ensure
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
