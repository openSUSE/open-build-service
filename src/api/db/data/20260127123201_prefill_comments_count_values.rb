# frozen_string_literal: true

class PrefillCommentsCountValues < ActiveRecord::Migration[7.2]
  def up
    # rubocop:disable-next Rails/SkipsModelValidations
    Comment.group(:commentable_type, :commentable_id)
           .select(:id, :commentable_type, :commentable_id, 'COUNT(id) as comments_count')
           .find_each.each do |comment|
      comment.commentable.update_columns(comments_count: comment.comments_count) if comment.commentable
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
