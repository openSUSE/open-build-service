class AddBackendcommentToPackage < ActiveRecord::Migration
  def change
    add_column :packages, :commit_opts, :string
  end
end
