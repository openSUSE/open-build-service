class BsRequestPolicy < ApplicationPolicy
  def create?
    # new request should not have an id (BsRequest#number)
    return false if @record.number
    # dont let user set approver other than himself unless he is admin
    ![nil, @user.login].include?(@record.approver) && !@user.is_admin? ? false : true
  end
end
