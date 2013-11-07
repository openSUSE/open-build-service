class AllowMultiplePackageDefinitionsInChannelLists < ActiveRecord::Migration
  def change
    remove_index :channel_binaries, :name_and_channel_binary_list_id
    add_index :channel_binaries, [:name, :channel_binary_list_id]
  end
end
