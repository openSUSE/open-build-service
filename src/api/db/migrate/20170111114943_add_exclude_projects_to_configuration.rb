class AddExcludeProjectsToConfiguration < ActiveRecord::Migration[5.0]
  def self.up
    add_column :configurations, :unlisted_projects_filter, :string
    add_column :configurations, :unlisted_projects_filter_description, :string
  end

  def self.down
    remove_column :configurations, :unlisted_projects_filter, :string
    remove_column :configurations, :unlisted_projects_filter_description, :string
  end
end
