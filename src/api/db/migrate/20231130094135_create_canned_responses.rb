class CreateCannedResponses < ActiveRecord::Migration[7.0]
  def change
    create_table :canned_responses, id: :bigint do |t|
      t.references :user, null: false, foreign_key: true, type: :integer
      t.string :title
      t.text :content

      t.timestamps
    end
  end
end
