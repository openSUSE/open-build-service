class AddLinkOutsideToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :url, :string, null: true
  end
end
