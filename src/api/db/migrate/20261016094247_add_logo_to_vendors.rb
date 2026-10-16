class AddLogoToVendors < ActiveRecord::Migration[8.1]
  def change
    add_column :vendors, :logo, :binary, limit: 5.megabytes
    add_column :vendors, :logo_content_type, :string, limit: 100
  end
end
