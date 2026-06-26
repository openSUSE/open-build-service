class AddModeratorIdAndModeratedAtColumnsToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :moderated_at, :datetime

    add_column :comments, :moderator_id, :integer
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :comments, :users, column: :moderator_id, name: 'moderated_comments_fk'
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
