class IncreaseTimestampPrecision < ActiveRecord::Migration[5.1]
  def up
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        change_column table, column.name, :datetime, limit: 6 if column.type == :datetime && column.name == 'updated_at'
      end
    end
  end

  def down
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        change_column table, column.name, :datetime if column.type == :datetime && column.name == 'updated_at'
      end
    end
  end
end
