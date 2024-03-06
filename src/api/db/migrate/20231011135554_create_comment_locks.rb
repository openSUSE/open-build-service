class CreateCommentLocks < ActiveRecord::Migration[7.0]
  def change
    create_table :comment_locks, id: :bigint do |t|
      t.string :commentable_type, null: false
      t.integer :commentable_id, null: false
      t.integer :moderator_id, null: false

      t.timestamps
    end

    add_index :comment_locks, %i[commentable_type commentable_id], unique: true
    add_foreign_key :comment_locks, :users, column: :moderator_id
  end
end
