class AddRepositoriesHostsystemIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :repositories, %w[hostsystem_id], name: :index_repositories_hostsystem_id, unique: true
  end
end
