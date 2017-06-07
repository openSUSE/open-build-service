class UseRailsEnumsIssuesTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:issues) do |t|
      t.column :new_state, :integer, limit: 2, default: nil
    end

    Issue.states.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Issue.connection.execute("UPDATE issues SET new_state='#{index}' WHERE state='#{Issue.states.key(index)}'")
    end

    remove_column :issues, :state
    rename_column :issues, :new_state, :state
  end

  def down
    change_table(:issues) do |t|
      t.column :new_state, "ENUM('OPEN', 'CLOSED', 'UNKNOWN')", default: nil
    end

    Issue.states.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Issue.connection.execute("UPDATE issues SET new_state='#{Issue.states.key(index)}' WHERE state='#{index}'")
    end

    remove_column :issues, :state
    rename_column :issues, :new_state, :state

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
