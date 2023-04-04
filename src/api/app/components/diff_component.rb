# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index, :commentable, :commented_lines, :range

  def initialize(diff:, file_index: nil, commentable: nil, commented_lines: [], range: (0..))
    super
    @diff = parse_diff(diff)
    @file_index = file_index
    @commentable = commentable
    @commented_lines = commented_lines
    @range = range
  end

  def render?
    diff.present?
  end

  def lines
    return [] unless diff.lines

    diff.lines[range] || []
  end

  private

  def parse_diff(content)
    DiffParser.new(content: content).call
  end
end
