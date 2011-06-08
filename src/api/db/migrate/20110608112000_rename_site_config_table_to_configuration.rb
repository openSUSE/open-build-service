class RenameSiteConfigTableToConfiguration < ActiveRecord::Migration
  def self.up
    rename_table :site_configs, :configurations
  end

  def self.down
    rename_table :configurations, :site_configs
  end
end
