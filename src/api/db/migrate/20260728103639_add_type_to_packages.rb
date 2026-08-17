class AddTypeToPackages < ActiveRecord::Migration[7.2]
  def change
    add_column :packages, :type, :string, limit: 255, null: true, default: nil
    add_index :packages, :type
  end
end
