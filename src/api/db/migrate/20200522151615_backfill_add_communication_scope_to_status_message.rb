class BackfillAddCommunicationScopeToStatusMessage < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    StatusMessage.unscoped.in_batches do |relation|
      # rubocop:disable-next Rails/SkipsModelValidations
      relation.update_all communication_scope: 0
      sleep(0.01)
    end
  end
end
