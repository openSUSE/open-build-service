# frozen_string_literal: true

class PrefillBsRequestActionsCountInBsRequest < ActiveRecord::Migration[8.1]
  def up
    BsRequestAction.group(:bs_request_id).select(:bs_request_id, 'COUNT(id) as bs_request_actions_count').each do |bs_request_action|
      # rubocop:disable-next Rails/SkipsModelValidations
      bs_request_action.bs_request.update_columns(bs_request_actions_count: bs_request_action.bs_request_actions_count)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
