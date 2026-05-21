class AddAnityaDistributionToProjects < ActiveRecord::Migration[7.2]
  def up
    add_column :projects, :anitya_distribution_name, :string
  end

  def down
    safety_assured { remove_column :projects, :anitya_distribution_name }
  end
end
