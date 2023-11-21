class AddRssSecretToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :rss_secret, :string, limit: 200, default: ''
  end
end
