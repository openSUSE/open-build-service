module HistoryElement
  class Base < ApplicationRecord
    belongs_to :user

    self.table_name = 'history_elements'

    class << self
      attr_accessor :description, :raw_type
      attr_accessor :comment, :raw_type
      attr_accessor :created_at, :raw_type
    end

    def color
      nil
    end
  end
end
