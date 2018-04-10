# frozen_string_literal: true
class CleanupEmptyProjects < ActiveRecord::Migration[4.2]
  def self.up
    add_column :configurations, :cleanup_empty_projects, :boolean, default: true
  end

  def self.down
    remove_column :configurations, :cleanup_empty_projects
  end
end
