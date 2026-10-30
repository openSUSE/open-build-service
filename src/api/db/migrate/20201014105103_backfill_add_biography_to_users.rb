class BackfillAddBiographyToUsers < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches do |relation|
      # rubocop:disable-next Rails/SkipsModelValidations
      relation.update_all biography: ''
      sleep(0.01) # throttle
    end
  end
end
