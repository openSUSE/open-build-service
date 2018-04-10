# frozen_string_literal: true
require 'delegate'

class BaseDecorator < SimpleDelegator
  def self.wrap(objects)
    objects.map { |object| new(object) }
  end

  # Returns ref to the object we're decorating
  def model
    __getobj__
  end
end
