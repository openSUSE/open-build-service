class ActiveRecord::Base
  def self.escape_sql(array)
    self.send(:sanitize_sql_array, array)
  end
end
