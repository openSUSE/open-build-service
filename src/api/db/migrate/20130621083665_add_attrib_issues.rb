class AddAttribIssues < ActiveRecord::Migration
  def self.up
    transaction do
      create_table :attrib_issues do |t|
        t.integer :attrib_id, null: false
        t.integer :issue_id, null: false
      end
      add_index :attrib_issues, [:attrib_id, :issue_id], unique: true

      ActiveRecord::Base.connection.execute(
        "alter table attrib_issues add FOREIGN KEY (attrib_id) references attribs (id);")
      ActiveRecord::Base.connection.execute(
        "alter table attrib_issues add FOREIGN KEY (issue_id) references issues (id);")

      add_column :attrib_types, :issue_list, :boolean, default: false
    end
  end

  def self.down
    transaction do
      drop_table :attrib_issues
      remove_column :attrib_types, :issue_list
    end
  end
end
