class AcceptRequestsJob

  def initialize
  end

  def perform
    User.current = User.find_by_login('Admin')
    BsRequest.find_requests_to_accept.each do |r|
      r.change_state('accepted', :comment => "Auto accept")
    end
  end

end


