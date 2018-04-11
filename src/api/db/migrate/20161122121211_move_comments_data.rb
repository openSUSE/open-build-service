# frozen_string_literal: true

class MoveCommentsData < ActiveRecord::Migration[5.0]
  def change
    ActiveRecord::Base.transaction do
      Comment.inheritance_column = nil
      Comment.find_each(batch_size: 5000) do |comment|
        /\AComment(?<type>.+)/ =~ comment.type
        type = 'BsRequest' if type == 'Request'
        unless ['Project', 'Package', 'BsRequest'].include? type
          # broken data, luckily only a comment, so forget about it
          comment.destroy
          next
        end
        comment.commentable_type = type
        comment.commentable_id = comment.project_id || comment.package_id || comment.bs_request_id
        comment.type = comment.project_id = comment.package_id = comment.bs_request_id = nil
        if comment.valid?
          comment.save!
        else
          # broken data, luckily only a comment, so forget about it
          comment.destroy
        end
      end
      Comment.inheritance_column = 'type'
    end
  end
end
