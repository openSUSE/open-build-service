class AddBinaryIdTracking < ActiveRecord::Migration[5.2]
  def change
    add_column :binary_releases, :binary_id, :string, charset: 'utf8'
    add_index :binary_releases, :binary_id
  end
end
