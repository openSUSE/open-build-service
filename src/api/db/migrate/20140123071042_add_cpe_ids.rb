class AddCpeIds < ActiveRecord::Migration
  def change
    add_column :products, :cpe, :string
  end
end
