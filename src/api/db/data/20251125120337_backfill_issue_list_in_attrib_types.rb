class BackfillIssueListInAttribTypes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    AttribType.unscoped.in_batches do |relation|
      relation.where(issue_list: nil).update_all(issue_list: false) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # Irreversible
  end
end
