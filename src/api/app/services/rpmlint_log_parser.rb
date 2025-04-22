class RpmlintLogParser
  attr_reader :errors, :badness, :warnings, :info

  def initialize(content: '')
    @content = content

    @errors = Hash.new(0)
    @badness = Hash.new(0)
    @warnings = Hash.new(0)
    @info = Hash.new(0)
  end

  def call
    @content.each_line do |line|
      parse_line(line)
    end

    self
  end

  private

  def parse_line(line)
    # Examples of line pattern matching:
    #
    # blueman.x86_64: E: env-script-interpreter (Badness: 9) /usr/bin/blueman-adapters /usr/bin/env python3
    # blueman.x86_64: W: empty-%post
    # virtualbox.src:564: W: macro-in-comment %_target_cpu
    # blueman.x86_64: I: polkit-untracked-privilege org.blueman.bluez.config (??:no:auth_admin_keep)
    # ruby2.5-rubygem-bigdecimal.x86_64: W: hidden-file-or-dir /usr/lib64/ruby/gems/2.5.0/gems/bigdecimal-3.1.4/ext/bigdecimal/.sitearchdir.time
    return unless (line_m = line.match(/^(?<packagearch>\S+): (?<level>E|I|W): (?<linter>\S+)(?<rest>.*)/))

    # Examples of packagearch pattern matching:
    #
    # blueman.x86_64
    # virtualbox.src:564
    # ruby2.5-rubygem-bigdecimal.x86_64
    package_arch_m = line_m[:packagearch].match(/(?<package>.+)(?:\.(?<architecture>[^:]+))(?::(?<linenumber>\d+))?/)
    package = package_arch_m[:package]

    case line_m[:level]
    when 'E'
      errors[package] += 1

      # We only parse Badness when we find an error
      badness[package] += ::Regexp.last_match[:badness].to_i if line_m[:rest] =~ /\(Badness: (?<badness>\d+)\)/
    when 'W'
      warnings[package] += 1
    when 'I'
      info[package] += 1
    end
  end
end
