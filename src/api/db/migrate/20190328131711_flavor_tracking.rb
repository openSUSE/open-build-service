class FlavorTracking < ActiveRecord::Migration[5.1]
  def change
    add_column :binary_releases, :flavor, :string, charset: 'utf8'
  end
end
