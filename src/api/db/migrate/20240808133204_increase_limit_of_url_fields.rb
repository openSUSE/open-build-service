class IncreaseLimitOfUrlFields < ActiveRecord::Migration[7.0]
  def up
    change_column :issue_trackers, :show_url, :string, limit: 8192
    change_column :tokens, :workflow_configuration_url, :string, limit: 8192
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
