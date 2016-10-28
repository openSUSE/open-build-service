class AddAdminEmailConfiguration < ActiveRecord::Migration
  def self.up
    unless Configuration.column_names.include? "admin_email"
      add_column :configurations, :admin_email, :string, default: "unconfigured@openbuildservice.org"
    end
  end

  def self.down
    remove_column :configurations, :admin_email
  end
end
