class ChangeIssueListToNotNullInAttribTypes < ActiveRecord::Migration[7.2]
  def up
    change_column_null :attrib_types, :issue_list, false
  end

  def down
    change_column_null :attrib_types, :issue_list, true
  end
end
