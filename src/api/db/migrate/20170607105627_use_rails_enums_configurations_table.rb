class UseRailsEnumsConfigurationsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:configurations) do |t|
      t.column :new_registration, :integer, limit: 2, default: 0
    end

    Configuration.registrations.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Configuration.connection.
        execute("UPDATE configurations SET new_registration='#{index}' WHERE registration='#{Configuration.registrations.key(index)}'")
    end

    remove_column :configurations, :registration
    rename_column :configurations, :new_registration, :registration
  end

  def down
    change_table(:configurations) do |t|
      t.column :new_registration, "ENUM('allow','confirmation','deny')", default: 'allow'
    end

    Configuration.registrations.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      Configuration.connection.
        execute("UPDATE configurations SET new_registration='#{Configuration.registrations.key(index)}' WHERE registration='#{index}'")
    end

    remove_column :configurations, :registration
    rename_column :configurations, :new_registration, :registration

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
