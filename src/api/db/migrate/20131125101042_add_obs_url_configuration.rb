class AddObsUrlConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :obs_url, :string
    remove_column :configurations, :errbit_url
  end

  def self.down
    remove_column :configurations, :obs_url
    add_column :configurations, :errbit_url, :string
  end
end
