# frozen_string_literal: true
class AddApiUrlToConfiguration < ActiveRecord::Migration[4.2]
  def self.up
    add_column :configurations, :api_url, :string
  end

  def self.down
    remove_column :configurations, :api_url
  end
end
