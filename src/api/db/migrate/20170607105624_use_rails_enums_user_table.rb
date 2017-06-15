class UseRailsEnumsUserTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:users) do |t|
      t.column :new_state, :integer, limit: 2, default: 0
    end

    User.states.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      User.connection.execute("UPDATE users SET new_state='#{index}' WHERE state='#{User.states.key(index)}'")
    end

    remove_column :users, :state
    rename_column :users, :new_state, :state
  end

  def down
    change_table(:users) do |t|
      t.column :new_state, "ENUM('unconfirmed','confirmed','locked','deleted','subaccount')", default: 'unconfirmed'
    end

    User.states.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      User.connection.execute("UPDATE users SET new_state='#{User.states.key(index)}' WHERE state='#{index}'")
    end

    remove_column :users, :state
    rename_column :users, :new_state, :state

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
