# frozen_string_literal: true
class StatusCount
  include ActiveModel::Model
  attr_accessor :code, :count
end
