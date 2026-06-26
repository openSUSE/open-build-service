class ChangeLabelTemplatesColorToString < ActiveRecord::Migration[7.0]
  def up
    safety_assured { change_column :label_templates, :color, :string, null: false }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
