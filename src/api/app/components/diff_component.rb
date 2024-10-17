# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index, :commentable, :commented_lines, :range, :source_file, :target_file, :source_rev, :target_rev

  def initialize(diff:, file_index: nil, commentable: nil, commented_lines: [], range: (0..), source_file: nil, target_file: nil, source_rev: nil, target_rev: nil)
    super
    @diff = parse_diff(diff)
    @file_index = file_index
    @commentable = commentable
    @commented_lines = commented_lines
    @range = range
    @source_file = source_file
    @target_file = target_file
    @source_rev = source_rev
    @target_rev = target_rev
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
