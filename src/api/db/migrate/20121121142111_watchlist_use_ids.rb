class WatchlistUseIds < ActiveRecord::Migration
  def up
    add_column :watched_projects, :project_id, :integer, after: :bs_user_id, null: false
    # Convert names to project ids
    WatchedProject.all.each do |wp|
      prj = Project.where(name: wp.name).first
      if prj
        wp.project_id = prj.id
        wp.save
      else
        wp.delete
      end
    end
    remove_column :watched_projects, :name
  end

  def down
    add_column :watched_projects, :name, :string, after: :bs_user_id, null: false
    # Convert db_project ids to names
    WatchedProject.all.each do |wp|
      wp.name = wp.project.name
      wp.save
    end
    remove_column :watched_projects, :project_id
  end
end
