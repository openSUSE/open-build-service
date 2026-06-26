class AddWorkflowRunToEventSubscription < ActiveRecord::Migration[6.1]
  def change
    add_column :event_subscriptions, :workflow_run_id, :integer
    add_index :event_subscriptions, :workflow_run_id
  end
end
