class AddBsRequestActionAcceptInfosBsRequestActionIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :bs_request_action_accept_infos, %w[bs_request_action_id], name: :index_bs_request_action_accept_infos_bs_request_action_id, unique: true
  end
end
