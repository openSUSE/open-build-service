class CommentLockingValidator < ActiveModel::Validator
  def validate(record)
    commentable = record.commentable
    return unless commentable
    return if commentable.comment_lock.blank?

    commentable_name = case commentable
                       when Package, Project
                         commentable.class.name.downcase
                       when BsRequest
                         'request'
                       when BsRequestAction
                         'request action'
                       end
    record.errors.add(:base, "This #{commentable_name} is locked for commenting")
  end
end
