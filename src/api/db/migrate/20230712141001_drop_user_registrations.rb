class DropUserRegistrations < ActiveRecord::Migration[7.0]
  def up
    drop_table :user_registrations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
