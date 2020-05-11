class AddBinaryIdTracking < ActiveRecord::Migration[5.2]
  def change
    change_table :binary_releases, bulk: true do |t|
      t.string :binary_id, charset: 'utf8'
      t.index :binary_id
    end
  end
end
