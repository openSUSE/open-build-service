class AddCpeidToBinaryRelease < ActiveRecord::Migration[4.2]
  def self.up
    add_column :binary_releases, :binary_cpeid, :string, charset: 'utf8'
  end

  def self.down
    remove_column :binary_releases, :binary_cpeid
  end
end
