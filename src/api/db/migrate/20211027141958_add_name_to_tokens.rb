class AddNameToTokens < ActiveRecord::Migration[6.1]
  def up
    add_column :tokens, :name, :string, limit: 64
    change_column_default :tokens, :name, ''
  end

  def down
    remove_column :tokens, :name
  end
end
