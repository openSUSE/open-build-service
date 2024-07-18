# frozen_string_literal: true

class RenameProjectReceiverRolesInEventSubscriptions < ActiveRecord::Migration[7.0]
  # rubocop:disable Rails/SkipsModelValidations
  def up
    EventSubscription.where(receiver_role: 'watcher').in_batches do |relation|
      relation.update_all receiver_role: 'project_watcher'
      sleep(0.01) # throttle
    end
    EventSubscription.where(receiver_role: 'source_watcher').in_batches do |relation|
      relation.update_all receiver_role: 'source_project_watcher'
      sleep(0.01) # throttle
    end
    EventSubscription.where(receiver_role: 'target_watcher').in_batches do |relation|
      relation.update_all receiver_role: 'target_project_watcher'
      sleep(0.01) # throttle
    end
  end

  def down
    EventSubscription.where(receiver_role: 'target_project_watcher').in_batches do |relation|
      relation.update_all receiver_role: 'target_project_watcher'
      sleep(0.01) # throttle
    end
    EventSubscription.where(receiver_role: 'source_project_watcher').in_batches do |relation|
      relation.update_all receiver_role: 'project_watcher'
      sleep(0.01) # throttle
    end
    EventSubscription.where(receiver_role: 'project_watcher').in_batches do |relation|
      relation.update_all receiver_role: 'watcher'
      sleep(0.01) # throttle
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
end
