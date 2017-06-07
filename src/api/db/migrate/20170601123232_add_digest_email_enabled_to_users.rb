class AddDigestEmailEnabledToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :digest_email_enabled, :boolean, default: false
  end
end
