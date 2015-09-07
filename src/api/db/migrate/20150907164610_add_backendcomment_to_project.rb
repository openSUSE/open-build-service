class AddBackendcommentToProject < ActiveRecord::Migration
  def change
    add_column :projects, :commit_opts, :string
  end
end
