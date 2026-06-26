# frozen_string_literal: true

class SetArchitecturesAvailableFieldToFalse < ActiveRecord::Migration[7.0]
  def up
    # rubocop:disable Rails/SkipsModelValidations
    Architecture.where(available: nil).update_all(available: false)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
