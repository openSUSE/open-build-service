class CommentRequest < Comment

  validates :bs_request, presence: true

  def check_delete_permissions
    # If you can review or if you are maintainer of the target of the request, you can delete the comment
    bs_request.is_reviewer?(User.current) || bs_request.is_target_maintainer?(User.current) || super
  end

  def create_notification(params = {})
    super
    BsRequest.find(self.bs_request_id).notify_parameters(params)
    params[:commenters] = involved_users(:bs_request_id, self.bs_request_id)

    # call the action
    Event::CommentForRequest.create params
  end
end
