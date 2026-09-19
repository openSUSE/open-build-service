class SetDefaultForDistroRemote < ActiveRecord::Migration[6.0]
  def up
    Distribution.unscoped.in_batches do |relation|
      # rubocop:disable-next Rails/SkipsModelValidations
      relation.update_all(remote: false)
      sleep(0.01)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
