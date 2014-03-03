class AddAdminEmailConfiguration < ActiveRecord::Migration
  def self.up
    add_column :configurations, :admin_email, :string, :default => "unconfigured@openbuildservice.org"
  end

  def self.down
    remove_column :configurations, :admin_email
  end
end
