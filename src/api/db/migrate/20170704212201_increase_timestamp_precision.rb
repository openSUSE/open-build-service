# frozen_string_literal: true

class IncreaseTimestampPrecision < ActiveRecord::Migration[5.1]
  def up
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        if column.type == :datetime && column.name == 'updated_at'
          change_column table, column.name, :datetime, limit: 6
        end
      end
    end
  end

  def down
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.columns(table).each do |column|
        if column.type == :datetime && column.name == 'updated_at'
          change_column table, column.name, :datetime
        end
      end
    end
  end
end
