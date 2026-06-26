class AddRequiredChecksToProjects < ActiveRecord::Migration[5.2]
  def change
    add_column :projects, :required_checks, :string
  end
end
