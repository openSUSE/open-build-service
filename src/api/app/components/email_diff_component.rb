# frozen_string_literal: true

# Renders a diff for HTML emails. Email clients do not load our stylesheets,
# so every line gets inline styles based on the state DiffParser assigns to it.
class EmailDiffComponent < ApplicationComponent
  LINE_STYLES = {
    'added' => 'background-color: #e6ffec;',
    'removed' => 'background-color: #ffebe9;',
    'range' => 'background-color: #f6f8fa; color: #57606a;',
    'comment' => 'color: #57606a;'
  }.freeze

  def initialize(diff:)
    super()
    @diff = diff
  end

  def render?
    @diff.present?
  end

  def lines
    DiffParser.new(content: @diff).call.lines
  end

  def line_style(line)
    LINE_STYLES.fetch(line.state, '')
  end
end
