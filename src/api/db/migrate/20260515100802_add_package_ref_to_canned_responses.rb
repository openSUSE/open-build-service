class AddPackageRefToCannedResponses < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_reference :canned_responses, :package, type: :integer
  end

  def down
    remove_reference :canned_responses, :package
  end
end
