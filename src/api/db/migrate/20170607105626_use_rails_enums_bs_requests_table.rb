class UseRailsEnumsBsRequestsTable < ActiveRecord::Migration[5.0]
  def up
    change_table(:bs_requests) do |t|
      t.column :new_priority, :integer, limit: 2, default: 2
    end

    BsRequest.priorities.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      BsRequest.connection.execute("UPDATE bs_requests SET new_priority='#{index}' WHERE priority='#{BsRequest.priorities.key(index)}'")
    end

    remove_column :bs_requests, :priority
    rename_column :bs_requests, :new_priority, :priority
  end

  def down
    change_table(:bs_requests) do |t|
      t.column :new_priority, "ENUM('critical', 'important', 'moderate', 'low')", default: 'moderate'
    end

    BsRequest.priorities.values.each do |index|
      # We need to use raw sql to avoid conflicts with the ActiveRecord::Enum
      # mapping defined in the model.
      # SQL enums start at 1, ActiveRecord::Enum usually at 0.
      BsRequest.connection.execute("UPDATE bs_requests SET new_priority='#{BsRequest.priorities.key(index)}' WHERE priority='#{index}'")
    end

    remove_column :bs_requests, :priority
    rename_column :bs_requests, :new_priority, :priority

    puts "WARNING: After rolling back the migration you need to remove the enum definition from the model"
  end
end
