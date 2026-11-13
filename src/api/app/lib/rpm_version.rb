# Compares package versions (rpmvercmp)
module RpmVersion
  TOKEN = /~|\^|\d+|[a-zA-Z]+/

  class << self
    # Returns 1 if left is newer, -1 if right is newer and 0 if both are equal.
    # Versions are split into numeric and alphabetic segments, everything else is a separator.
    # e.g. 0.16+git20101166 > 0.16+git20101114, 1.10 > 1.9, 1.0~rc1 < 1.0 < 1.0^git1 < 1.0.1
    # Only the version is compared, the release (after the first "-") is ignored: 2.4.1-3.5 == 2.4.1-bp161.1.2
    # A missing version (nil) is older than any version.
    def compare(left, right)
      left_tokens = tokens(left)
      right_tokens = tokens(right)

      [left_tokens.size, right_tokens.size].max.times do |index|
        result = compare_tokens(left_tokens[index], right_tokens[index])
        return result unless result.zero?
      end

      0
    end

    private

    def compare_tokens(left, right)
      return 0 if left == right

      compare_markers(left, right) || compare_segments(left, right)
    end

    def compare_markers(left, right)
      return -1 if left == '~'
      return 1 if right == '~'
      return -1 if left.nil?
      return 1 if right.nil?
      return -1 if left == '^'

      1 if right == '^'
    end

    # Numbers are compared as numbers (1.10 > 1.9, 01 == 1) and letters alphabetically.
    # A numeric segment is newer than an alphabetic one.
    def compare_segments(left, right)
      left_numeric = left.match?(/\A\d/)
      return left_numeric ? 1 : -1 if left_numeric != right.match?(/\A\d/)

      left_numeric ? left.to_i <=> right.to_i : left <=> right
    end

    def tokens(version)
      version.to_s.split('-', 2).first.to_s.scan(TOKEN)
    end
  end
end
