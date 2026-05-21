class AddEnabledToToken < ActiveRecord::Migration[7.0]
  def change
    add_column :tokens, :enabled, :boolean, default: true, null: false
  end
end
