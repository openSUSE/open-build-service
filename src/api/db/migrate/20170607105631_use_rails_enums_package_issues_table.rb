class UseRailsEnumsPackageIssuesTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:package_issues) do |t|
      t.column :new_change, :integer, limit: 2, default: nil
    end

    PackageIssue.changes.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      PackageIssue.connection.
        execute("UPDATE package_issues SET new_change='#{index}' WHERE package_issues.change='#{PackageIssue.changes.key(index)}'")
    end

    remove_column :package_issues, :change
    rename_column :package_issues, :new_change, :change
  end

  def down
    change_table(:package_issues) do |t|
      t.column :new_change, "ENUM('added', 'deleted', 'changed', 'kept')", default: nil
    end

    PackageIssue.changes.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      PackageIssue.connection.
        execute("UPDATE package_issues SET new_change='#{PackageIssue.changes.key(index)}' WHERE package_issues.change='#{index}'")
    end

    remove_column :package_issues, :change
    rename_column :package_issues, :new_change, :change

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
