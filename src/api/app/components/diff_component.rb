# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index

  def initialize(diff:, file_index:)
    super
    @diff = parse_diff(diff)
    @file_index = file_index
  end

  def render?
    diff.present?
  end

  private

  def parse_diff(content)
    DiffParser.new(content: content).call
  end
end
