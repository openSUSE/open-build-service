class IncreaseBinaryReleasesLimit < ActiveRecord::Migration[7.0]
  def up
    safety_assured { change_column :binary_releases, :id, :bigint }
    safety_assured { change_column :binary_releases, :on_medium_id, :bigint }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
    # in theory we could implement some complex handling here, but it is unlikely that we revert
  end
end
