class RemoveIndexBsRequestActionAcceptInfoBsRequestActionId < ActiveRecord::Migration[7.0]
  def change
    remove_index 'bs_request_action_accept_infos', 'bs_request_action_id', name: 'bs_request_action_id'
  end
end
