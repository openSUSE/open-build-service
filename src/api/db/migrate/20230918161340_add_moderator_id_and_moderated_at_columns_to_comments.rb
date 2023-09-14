class AddModeratorIdAndModeratedAtColumnsToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :moderated_at, :datetime

    add_column :comments, :moderator_id, :integer
    add_foreign_key :comments, :users, column: :moderator_id, name: 'moderated_comments_fk'
  end
end
