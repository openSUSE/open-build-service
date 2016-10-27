class CommentRequest < Comment
  validates :bs_request, presence: true

  def check_delete_permissions
    # if you are maintainer of the target of the request, you can delete the comment
    bs_request.is_target_maintainer?(User.current) || super
  end

  def create_notification(params = {})
    super
    params = BsRequest.find(bs_request_id).notify_parameters(params)
    params[:commenters] = involved_users(:bs_request_id, bs_request_id)

    # call the action
    Event::CommentForRequest.create params
  end
end
