class RpmLintComponent < ApplicationComponent
  def render?
    @errors.map(&:second).any?(&:positive?)
  end

  def initialize(rpmlint_log_parser:)
    super

    threshold_filter = ->(key, _value) { rpmlint_log_parser.errors[key].positive? }
    badness_sorter = ->(a, b) { rpmlint_log_parser.badness[a[0]] <=> rpmlint_log_parser.badness[b[0]] }

    @errors = rpmlint_log_parser.errors.select(&threshold_filter).sort(&badness_sorter).reverse
    @warnings = rpmlint_log_parser.warnings.select(&threshold_filter)
    @info = rpmlint_log_parser.info.select(&threshold_filter)
    @badness = rpmlint_log_parser.badness.select(&threshold_filter).sort(&badness_sorter).reverse
  end

  def issues_chart_data
    [{ name: 'Errors', data: @errors },
     { name: 'Warnings', data: @warnings },
     { name: 'Info', data: @info }]
  end

  def badness_chart_data
    [{ name: 'Badness', data: @badness }]
  end
end
