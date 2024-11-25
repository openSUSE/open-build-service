class DiffParser
  attr_reader :lines

  def initialize(content:)
    @content = content || ''
    @original_index = 0
    @changed_index = 0
    @last_original_index = 0
    @last_changed_index = 0
    @lines = []
    @dimapa = DiMaPa.new
  end

  def call
    @content.each_line.with_index do |line, line_index|
      @state = parse_line(line)

      @lines << create_line(line, line_index)

      @last_original_index = @original_index
      @last_changed_index = @changed_index
    end

    @blocks = @lines.slice_when do |b, a|
      (b.state.in?(%w[added removed]) ^ a.state.in?(%w[added removed])) || (b.state == 'added' && b.state == 'removed')
    end

    generate_inline_diffs
    self
  end

  def max_digits
    [@last_original_index, @last_changed_index].max.digits.length
  end

  private

  # rubocop:disable Metrics/CyclomaticComplexity
  def generate_inline_diffs
    @blocks.each do |block|
      next unless added_and_removed?(block)

      removed_string = extract_diff_content(block, 'removed')
      added_string = extract_diff_content(block, 'added')

      processed_lines = inline_diff(removed_string, added_string)

      block.zip(processed_lines) do |line, content|
        sign = line.state == 'added' ? '+' : '-'

        # Known scenario https://github.com/openSUSE/open-build-service/pull/17006
        # Notify the exception if a different unexpected scenario happen instead
        if content.nil? && line.content != '+'
          ::Airbrake.notify("Unknown scenario in generate_inline_diffs - content is nil but line is not '+': line='#{line.to_json}'")
        end

        line.content = "#{sign}#{content}" unless full_line_diff(content)
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def added_and_removed?(block)
    block.any? { |l| l.state == 'added' } && block.any? { |l| l.state == 'removed' }
  end

  def extract_diff_content(block, state)
    # Unescaping HTML because we don't want to diff HTML entities, but the contents of the strings
    block.map { |l| l.state == state ? CGI.unescapeHTML(l.content[1..]) : '' }.join
  end

  def full_line_diff(line)
    return false unless line
    return false unless line.start_with?('<')
    return false unless line.end_with?(">\n", '>')
    return false unless line.scan(/<.*?>/).size == 2

    true
  end

  def inline_diff(removed_string, added_string)
    diff = @dimapa.diff_main(removed_string, added_string)
    # This makes the diff seem more semantic to humans. Otherwise it might look a bit jarring
    @dimapa.diff_cleanup_semantic(diff)

    deleted = ''
    inserted = ''
    diff.each do |action, content|
      # We need to do this for every line, since every line is then rendered as its own div later.
      # We also want to avoid the situation where the end of the span is placed after the last line, creating another line

      parsed_content = prepare_content(content, action)
      deleted += parsed_content unless action == :insert
      inserted += parsed_content unless action == :delete
    end

    deleted.lines + inserted.lines
  end

  def prepare_content(content, action)
    parsed_content = action == :equal ? CGI.escapeHTML(content) : content.lines(chomp: true).map { |d| "<span class=\"inline-diff\">#{CGI.escapeHTML(d)}</span>" }.join("\n")
    parsed_content += "\n" if content.end_with?("\n") && !parsed_content.end_with?("\n")
    parsed_content
  end

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
    DiffParser::Line.new(content: CGI.escapeHTML(line), state: @state, index: line_index + 1, original_index: final_original_index, changed_index: final_changed_index)
  end

  def final_original_index
    return if %w[comment range].include?(@state)

    @original_index unless @last_original_index == @original_index
  end

  def final_changed_index
    return if %w[comment range].include?(@state)

    @changed_index unless @last_changed_index == @changed_index
  end
end
