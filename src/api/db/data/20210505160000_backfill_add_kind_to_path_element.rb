class BackfillAddKindToPathElement < ActiveRecord::Migration[6.0]
  def up
    PathElement.unscoped.in_batches do |relation|
      relation.update_all kind: 'standard'
      sleep(0.01)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
