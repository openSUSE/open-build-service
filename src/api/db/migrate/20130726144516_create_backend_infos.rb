class CreateBackendInfos < ActiveRecord::Migration
  def change
    create_table :backend_infos do |t|
      t.string :key, null: false
      t.string :value, null: false
      t.timestamps
    end
  end
end
