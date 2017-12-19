class AcceptRequestsJob < ApplicationJob
  def perform
    User.current = User.find_by_login('Admin')
    BsRequest.to_accept.each do |r|
      begin
        r.change_state('accepted', comment: 'Auto accept')
      rescue BsRequestAction::UnknownProject,
             Package::UnknownObjectError,
             Package::ReadAccessError,
             BsRequestAction::UnknownTargetPackage,
             BsRequestPermissionCheck::NotExistingTarget,
             Project::UnknownObjectError => e
        r.change_state('revoked', comment: "Accept failed with: #{e.message}")
      end
    end
  end
end
