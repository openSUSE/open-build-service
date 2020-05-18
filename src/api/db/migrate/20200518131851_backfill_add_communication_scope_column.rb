class BackfillAddCommunicationScopeColumn < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    # rubocop:disable Rails/SkipsModelValidations
    StatusMessage.unscoped.in_batches do |relation|
      relation.update_all communication_scope: 0
      sleep(0.01)
    end
    # Temporarily duplicated in Announcement
    Announcement.unscoped.in_batches do |relation|
      relation.update_all communication_scope: 0
      sleep(0.01)
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
