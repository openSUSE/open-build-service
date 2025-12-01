# frozen_string_literal: true

class AddDefaultSubscriptionForWorkflowRunFail < ActiveRecord::Migration[7.0]
  def up
    # Create default subscriptions for Event::WorkflowRunFail
    # These subscriptions will be used when a workflow run fails and the user doesn't have a specific subscription
    
    # token_executor role - instant_email channel
    EventSubscription.find_or_create_by!(
      eventtype: 'Event::WorkflowRunFail',
      receiver_role: 'token_executor',
      user_id: nil,
      group_id: nil,
      channel: :instant_email
    ) do |subscription|
      subscription.enabled = true
    end

    # token_executor role - web channel
    EventSubscription.find_or_create_by!(
      eventtype: 'Event::WorkflowRunFail',
      receiver_role: 'token_executor',
      user_id: nil,
      group_id: nil,
      channel: :web
    ) do |subscription|
      subscription.enabled = true
    end

    # token_member role - instant_email channel
    EventSubscription.find_or_create_by!(
      eventtype: 'Event::WorkflowRunFail',
      receiver_role: 'token_member',
      user_id: nil,
      group_id: nil,
      channel: :instant_email
    ) do |subscription|
      subscription.enabled = true
    end

    # token_member role - web channel
    EventSubscription.find_or_create_by!(
      eventtype: 'Event::WorkflowRunFail',
      receiver_role: 'token_member',
      user_id: nil,
      group_id: nil,
      channel: :web
    ) do |subscription|
      subscription.enabled = true
    end
  end

  def down
    EventSubscription.where(
      eventtype: 'Event::WorkflowRunFail',
      user_id: nil,
      group_id: nil
    ).destroy_all
  end
end
