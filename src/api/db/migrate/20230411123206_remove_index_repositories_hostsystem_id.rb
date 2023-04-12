class RemoveIndexRepositoriesHostsystemId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'repositories', 'hostsystem_id', name: 'hostsystem_id'
  end
end
