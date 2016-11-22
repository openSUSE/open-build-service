class MoveCommentsData < ActiveRecord::Migration[5.0]
  def change
    ActiveRecord::Base.transaction do
      Comment.inheritance_column = nil
      Comment.find_each(batch_size: 5000) do |comment|
        /\AComment(?<type>.+)/ =~ comment.type
        raise "Uncorrected type for comment with id #{comment.id}" unless ['Project', 'Package', 'BsRequest'].include? type
        comment.commentable_type = type
        comment.commentable_id = comment.project_id || comment.package_id || comment.bs_request_id
        comment.type = comment.project_id = comment.package_id = comment.bs_request_id = nil
        comment.save!
      end
      Comment.inheritance_column = 'type'
    end
  end
end
