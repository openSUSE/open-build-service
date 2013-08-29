class AddLockVersionToEvents < ActiveRecord::Migration
  def change
    add_column :events, :lock_version, :integer, default: 0, null: false
  end
end
