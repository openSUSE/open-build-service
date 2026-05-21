class AddProjectIdToCannedResponses < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :canned_responses, :projects, on_delete: :nullify
    ensure
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end

  def down
    remove_foreign_key :canned_responses, :projects
  end
end
