class CreateFake < ActiveRecord::Migration[7.0]
  def change
    create_table :fakes, id: :bigint do |t|
      t.text :reason, null: false

      t.timestamps
    end
  end
end
