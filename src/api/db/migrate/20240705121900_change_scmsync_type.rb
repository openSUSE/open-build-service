class ChangeScmsyncType < ActiveRecord::Migration[6.1]
  def up
    safety_assured { change_column :projects, :scmsync, :text }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
    # in theory we could implement some complex handling here, but it is unlikely that we revert
  end
end
