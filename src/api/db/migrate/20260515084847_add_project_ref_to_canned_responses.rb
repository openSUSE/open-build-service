class AddProjectRefToCannedResponses < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_reference :canned_responses, :project, type: :integer
  end

  def down
    remove_reference :canned_responses, :project
  end
end
