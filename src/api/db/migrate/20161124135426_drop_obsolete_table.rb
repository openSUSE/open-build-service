class DropObsoleteTable < ActiveRecord::Migration
  def up
    drop_table :bs_request_histories
  rescue ActiveRecord::StatementInvalid
    # just drop in case it exists, it is not used since two years
  end

  def down
  end
end
