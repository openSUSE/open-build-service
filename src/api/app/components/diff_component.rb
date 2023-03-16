# frozen_string_literal: true

class DiffComponent < ApplicationComponent
  attr_reader :diff, :file_index, :commentable, :commented_lines

  def initialize(diff:, file_index:, commentable: nil, commented_lines: [])
    super
    @diff = parse_diff(diff)
    @file_index = file_index
    @commentable = commentable
    @commented_lines = commented_lines
  end

  def render?
    diff.present?
  end

  private

  def parse_diff(content)
    DiffParser.new(content: content).call
  end
end
