class AddCensoredToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :censored, :boolean, default: false, null: false
    add_index :users, :censored
  end
end
