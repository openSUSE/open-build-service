
class AddChannelIndex < ActiveRecord::Migration
  def self.up
    # broken db? better parse again everything
    Channel.all.destroy_all

    add_index :channels, [:package_id], unique: true, :name => "index_unique"
  
    PackageKind.all.where(kind: "channel").each{|pk| pk.package.update_backendinfo}
  end

  def self.down
    remove_index :channels, :name => "index_unique"
  end
end
