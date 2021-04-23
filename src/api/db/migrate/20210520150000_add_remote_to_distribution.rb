class AddRemoteToDistribution < ActiveRecord::Migration[6.0]
  def up
    add_column :distributions, :remote, :boolean
    change_column_default :distributions, :remote, false
  end

  def down
    remove_column :distributions, :remote
  end
end
