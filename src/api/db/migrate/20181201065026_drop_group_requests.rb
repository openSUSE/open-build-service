class DropGroupRequests < ActiveRecord::Migration[5.2]
  def up
    drop_table :group_request_requests
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
