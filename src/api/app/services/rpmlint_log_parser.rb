class RpmlintLogParser
  attr_reader :errors, :badness, :warnings, :info, :results

  def initialize(content, repo: nil, arch: nil)
    @content = content || ''
    @repo = repo
    @arch = arch

    @errors = Hash.new(0)
    @badness = Hash.new(0)
    @warnings = Hash.new(0)
    @info = Hash.new(0)
    @results = []
  end

  def call
    @content.each_line.with_index do |line, index|
      parse_line(line, index)
    end

    self
  end

  private

  def parse_line(line, index) # rubocop:disable Metrics/CyclomaticComplexity
    # Examples of line pattern matching:
    #
    # blueman.x86_64: E: env-script-interpreter (Badness: 9) /usr/bin/blueman-adapters /usr/bin/env python3
    # blueman.x86_64: W: empty-%post
    # virtualbox.src:564: W: macro-in-comment %_target_cpu
    # blueman.x86_64: I: polkit-untracked-privilege org.blueman.bluez.config (??:no:auth_admin_keep)
    # ruby2.5-rubygem-bigdecimal.x86_64: W: hidden-file-or-dir /usr/lib64/ruby/gems/2.5.0/gems/bigdecimal-3.1.4/ext/bigdecimal/.sitearchdir.time
    return unless (line_m = line.match(/^(?<packagearch>\S+): (?<level>E|I|W): (?<linter>\S+)(?<error_message>.*)/))

    # Examples of packagearch pattern matching:
    #
    # blueman.x86_64
    # virtualbox.src:564
    # ruby2.5-rubygem-bigdecimal.x86_64
    #
    # Example of packagearch pattern matching which must be excluded:
    #
    # (none): W: unknown check BackportsPolicyChecks, skipping
    package_arch_m = line_m[:packagearch].match(/(?<package>.+)(?:\.(?<architecture>[^:]+))(?::(?<linenumber>\d+))?/)

    return if package_arch_m.nil?

    package = package_arch_m[:package]

    result = { location: line_m[:packagearch], level: line_m[:level], linter: line_m[:linter], error_message: line_m[:error_message],
               badness: 0, line: index + 1, repo: @repo, arch: @arch }

    case line_m[:level]
    when 'E'
      errors[package] += 1

      # We only parse Badness when we find an error
      badness_value = (::Regexp.last_match[:badness].to_i if line_m[:error_message] =~ /\(Badness: (?<badness>\d+)\)/) || 1
      badness[package] += badness_value
      result[:badness] = badness_value
    when 'W'
      warnings[package] += 1
    when 'I'
      info[package] += 1
    end

    results << result
  end
end
