class CreateTableItem < ActiveRecord::Migration[5.1]
  def change
    create_table :table_items do |t|
      t.string :name
    end
  end
end
