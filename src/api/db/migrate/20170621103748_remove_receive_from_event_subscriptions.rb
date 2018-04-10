# frozen_string_literal: true
class RemoveReceiveFromEventSubscriptions < ActiveRecord::Migration[5.0]
  def change
    remove_column :event_subscriptions, :receive, :boolean
  end
end
