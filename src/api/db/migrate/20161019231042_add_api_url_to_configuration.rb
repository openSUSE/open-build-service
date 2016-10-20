class AddApiUrlToConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :api_url, :string
  end

  def self.down
    remove_column :configurations, :api_url
  end
end
