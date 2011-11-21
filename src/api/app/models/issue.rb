# Fake an 'Issue' model
class Issue < ActiveRecord::Base
  class_inheritable_accessor :columns
  self.columns = []

  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  column :name, :string             # 1234
  column :long_name, :string        # bnc#1234
  column :issue_tracker, :string    # bnc
  column :description, :text
  column :show_url, :string
end
