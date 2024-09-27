class MakeLabelTemplatesNameAndColorRequired < ActiveRecord::Migration[7.0]
  def change
    change_column_null :label_templates, :name, false
    change_column_null :label_templates, :color, false
  end
end
