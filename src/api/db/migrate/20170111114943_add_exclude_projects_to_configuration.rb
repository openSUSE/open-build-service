# frozen_string_literal: true
class AddExcludeProjectsToConfiguration < ActiveRecord::Migration[5.0]
  def self.up
    add_column :configurations, :unlisted_projects_filter, :string, default: '^home:.+'
    add_column :configurations, :unlisted_projects_filter_description, :string, default: 'home projects'
  end

  def self.down
    remove_column :configurations, :unlisted_projects_filter, :string
    remove_column :configurations, :unlisted_projects_filter_description, :string
  end
end
