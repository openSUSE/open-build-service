class ChangeChannelDisabledDefault < ActiveRecord::Migration[6.0]
  # rubocop:disable Rails/ReversibleMigration
  def change
    change_column_default :channels, :disabled, false
  end
  # rubocop:enable Rails/ReversibleMigration
end
