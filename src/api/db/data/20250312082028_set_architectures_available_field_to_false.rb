# frozen_string_literal: true

class SetArchitecturesAvailableFieldToFalse < ActiveRecord::Migration[7.0]
  def up
    # rubocop:disable-next Rails/SkipsModelValidations
    Architecture.where(available: nil).update_all(available: false)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
