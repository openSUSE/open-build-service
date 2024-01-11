class AddThemeToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :color_theme, :integer, default: 0, null: false
  end
end
