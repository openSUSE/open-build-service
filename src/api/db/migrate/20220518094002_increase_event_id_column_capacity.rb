class IncreaseEventIdColumnCapacity < ActiveRecord::Migration[6.1]
  def up
    safety_assured { change_column :events, :id, :bigint, auto_increment: true }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
