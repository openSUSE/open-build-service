class AddCategoryToReport < ActiveRecord::Migration[7.0]
  def change
    add_column :reports, :category, :integer, default: 99
  end
end
