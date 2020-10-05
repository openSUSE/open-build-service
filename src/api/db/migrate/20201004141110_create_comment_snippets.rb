class CreateCommentSnippets < ActiveRecord::Migration[6.0]
  def change
    create_table :comment_snippets, id: :integer do |t|
      t.string :title, charset: 'utf8', null: false
      t.text :body, null: false
      t.references :user, type: :integer, null: false, foreign_key: true

      t.timestamps
    end
  end
end
