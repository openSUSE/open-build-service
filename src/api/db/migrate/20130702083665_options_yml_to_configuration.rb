class OptionsYmlToConfiguration < ActiveRecord::Migration
  def self.up
      execute "alter table configurations add column configurations.registration enum('allow', 'confirmation', 'never') DEFAULT 'allow';"

      add_column :configurations, :anonymous, :boolean, default: true
      add_column :configurations, :default_access_disabled, :boolean, default: false
      add_column :configurations, :allow_user_to_create_home_project, :boolean, default: true
      add_column :configurations, :disallow_group_creation, :boolean, default: false
      add_column :configurations, :change_password, :boolean, default: true
      add_column :configurations, :hide_private_options, :boolean, default: false
      add_column :configurations, :gravatar, :boolean, default: true
      add_column :configurations, :enforce_project_keys, :boolean, default: false
      add_column :configurations, :download_on_demand, :boolean, default: true
      add_column :configurations, :multiaction_notify_support, :boolean, default: true
      add_column :configurations, :download_url, :string
      add_column :configurations, :ymp_url, :string
      add_column :configurations, :errbit_url, :string
      add_column :configurations, :bugzilla_url, :string
      add_column :configurations, :http_proxy, :string
      add_column :configurations, :no_proxy, :string
      add_column :configurations, :theme, :string

      # update database from file
      old = CONFIG['global_write_through']
      CONFIG['global_write_through'] = false
      ::Configuration.first.update_from_options_yml()
      CONFIG['global_write_through'] = old
  end

  def self.down
      remove_column :configurations, :anonymous
      remove_column :configurations, :registration
      remove_column :configurations, :default_access_disabled
      remove_column :configurations, :allow_user_to_create_home_project
      remove_column :configurations, :disallow_group_creation
      remove_column :configurations, :hide_private_options
      remove_column :configurations, :gravatar
      remove_column :configurations, :change_password
      remove_column :configurations, :enforce_project_keys
      remove_column :configurations, :download_on_demand
      remove_column :configurations, :multiaction_notify_support
      remove_column :configurations, :download_url
      remove_column :configurations, :ymp_url
      remove_column :configurations, :errbit_url
      remove_column :configurations, :bugzilla_url
      remove_column :configurations, :http_proxy
      remove_column :configurations, :no_proxy
      remove_column :configurations, :theme
  end
end
