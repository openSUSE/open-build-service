class AddInBetaToUser < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :in_beta, :boolean, default: false, index: true
  end
end
