# frozen_string_literal: true

require 'ostruct'

class Package < ApplicationRecord
  def develpackage?
    develpackage
  end
end