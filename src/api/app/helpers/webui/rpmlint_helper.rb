module Webui::RpmlintHelper
  def lint_description(lint:, content:)
    # Look for the lint followed by a space or newline.
    header_pattern = /[WE]:\s+#{Regexp.escape(lint)}(\s|$)/

    # The content may have multiple entries of a lint
    # find the position of the last lint match
    last_match_pos = content.rindex(header_pattern)
    return if last_match_pos.nil?

    after_header = content[last_match_pos..]
    lines = after_header.split("\n")
    lines.shift

    description = []
    lines.each do |line|
      trimmed = line.strip

      break if trimmed.empty?
      break if /:\s+[WE]:\s+/.match?(line)

      description << trimmed
    end

    description.join(' ').gsub(/\s+/, ' ').strip
  end

  def packaging_checks_link(lint)
    "https://en.opensuse.org/openSUSE:Packaging_checks##{lint}"
  end
end
