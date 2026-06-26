class AddCommentsCountToCommentable < ActiveRecord::Migration[7.2]
  def change
    add_column :projects, :comments_count, :integer, default: 0, null: false
    add_column :packages, :comments_count, :integer, default: 0, null: false
    add_column :reports, :comments_count, :integer, default: 0, null: false
    add_column :bs_requests, :comments_count, :integer, default: 0, null: false
    add_column :bs_request_actions, :comments_count, :integer, default: 0, null: false

    add_index :projects, :comments_count
    add_index :packages, :comments_count
    add_index :reports, :comments_count
    add_index :bs_requests, :comments_count
    add_index :bs_request_actions, :comments_count
  end
end
