class CreateSavedReplies < ActiveRecord::Migration[6.0]
  def change
    create_table :saved_replies, id: :integer do |t|
      t.references :user, null: false, type: :integer
      t.string :title
      t.string :body

      t.timestamps
    end
  end
end
