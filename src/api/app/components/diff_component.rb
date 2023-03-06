# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index, :commentable

  def initialize(diff:, file_index:, commentable: nil)
    super
    @diff = parse_diff(diff)
    @file_index = file_index
    @commentable = commentable
  end

  def render?
    diff.present?
  end

  private

  def parse_diff(content)
    DiffParser.new(content: content).call
  end
end
