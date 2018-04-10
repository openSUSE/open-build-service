# frozen_string_literal: true
class ActiveRecord::Base
  def self.escape_sql(array)
    send(:sanitize_sql_array, array)
  end
end
