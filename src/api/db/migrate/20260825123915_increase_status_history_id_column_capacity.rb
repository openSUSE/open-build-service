class IncreaseStatusHistoryIdColumnCapacity < ActiveRecord::Migration[8.1]
  def up
    safety_assured { change_column :status_histories, :id, :bigint, auto_increment: true }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
