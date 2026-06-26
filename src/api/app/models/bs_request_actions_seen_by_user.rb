class BsRequestActionsSeenByUser < ApplicationRecord
  belongs_to :bs_request_action
  belongs_to :user

  after_create do |_record|
    RabbitmqBus.send_to_bus('metrics', 'bs_request_action,seen=true count=1')
  end

  after_destroy do |_record|
    RabbitmqBus.send_to_bus('metrics', 'bs_request_action,seen=false count=1')
  end
end

# == Schema Information
#
# Table name: bs_request_actions_seen_by_users
#
#  bs_request_action_id :bigint           not null, indexed => [user_id]
#  user_id              :bigint           not null, indexed => [bs_request_action_id]
#
# Indexes
#
#  bs_request_actions_seen_by_users_index  (bs_request_action_id,user_id)
#
