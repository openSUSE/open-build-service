class DiffParser
  attr_reader :lines

  def initialize(content:)
    @content = content || ''
    @original_index = 0
    @changed_index = 0
    @last_original_index = 0
    @last_changed_index = 0
    @lines = []
  end

  def call
    @content.each_line.with_index do |line, line_index|
      @state = parse_line(line)

      @lines << create_line(line, line_index)

      @last_original_index = @original_index
      @last_changed_index = @changed_index
    end

    self
  end

  def max_digits
    [@last_original_index, @last_changed_index].max.digits.length
  end

  private

  def parse_line(line)
    case line
    when /^ /
      @original_index += 1
      @changed_index += 1
      'unchanged'
    when /^@@ -(?<original_index>\d+).+\+(?<changed_index>\d+),/
      @original_index = Regexp.last_match[:original_index].to_i - 1
      @changed_index = Regexp.last_match[:changed_index].to_i - 1
      'range'
    when /^-/
      @original_index += 1
      'removed'
    when /^[+]/
      @changed_index += 1
      'added'
    else
      'comment'
    end
  end

  def create_line(line, line_index)
    DiffParser::Line.new(content: line, state: @state, index: line_index + 1, original_index: final_original_index, changed_index: final_changed_index)
  end

  def final_original_index
    return if ['comment', 'range'].include?(@state)

    @original_index unless @last_original_index == @original_index
  end

  def final_changed_index
    return if ['comment', 'range'].include?(@state)

    @changed_index unless @last_changed_index == @changed_index
  end
end
