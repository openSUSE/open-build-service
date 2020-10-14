class AddBiographyToUsers < ActiveRecord::Migration[6.0]
  def up
    add_column :users, :biography, :string
    change_column_default :users, :biography, ''
  end

  def down
    remove_column :users, :biography
  end
end
