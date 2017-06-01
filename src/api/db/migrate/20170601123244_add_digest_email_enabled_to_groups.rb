class AddDigestEmailEnabledToGroups < ActiveRecord::Migration[5.0]
  def change
    add_column :groups, :digest_email_enabled, :boolean, default: false
  end
end
