# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index, :commentable, :commented_lines, :range, :source_file, :target_file, :file_name

  def initialize(diff:, file_index: nil, commentable: nil, commented_lines: [], range: (0..), source_file: nil, target_file: nil, file_name: nil)
    super
    @diff = parse_diff(diff)
    @file_index = file_index
    @commentable = commentable
    @commented_lines = commented_lines
    @range = range
    @source_file = source_file
    @target_file = target_file
    @file_name = file_name
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
