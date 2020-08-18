module BsRequestService
  class ActionForwarder
    def initialize(bs_request)
      @bs_request = bs_request
      @bs_request_actions = bs_request.bs_request_actions
    end

    def forwarding_options
      forwarding_options = []
      @bs_request_actions.each do |action|
        forwarding_options.append(Hash[action.id, BsRequestActionService::Forwardable.new(action).possible_targets])
      end
      forwarding_options
    end

    def forward_actions_in_single_request(fwd_targets)
      new_request = BsRequest.new
      BsRequest.transaction do
        fwd_targets.each do |target|
          bs_request_action = @bs_request_actions.where(id: target['req_action_id']).first
          new_request.bs_request_actions << BsRequestActionService::Forwardable.new(bs_request_action)
                                                                               .create(target['tgt_prj'], target['tgt_pkg'])
        end
        new_request.save!
      end
      new_request
    end
  end
end
