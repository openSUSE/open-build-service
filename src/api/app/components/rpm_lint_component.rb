class RpmLintComponent < ApplicationComponent
  attr_reader :raw_data

  def initialize(raw_data: [])
    @raw_data = raw_data
  end

  def issues_chart_data
    threshold_filter = lambda { |key, value| raw_data[:errors][key] > 0 }
    badness_sorter = lambda { |a, b|
      raw_data[:badness][a[0]] <=> raw_data[:badness][b[0]]
    }

    errors = raw_data[:errors].select(&threshold_filter).sort(&badness_sorter).reverse.to_h

    warnings = raw_data[:warnings].select(&threshold_filter).sort(&badness_sorter).reverse.to_h

    info = raw_data[:info].select(&threshold_filter).sort(&badness_sorter).reverse.to_h

    [{name: 'Errors'}.merge({ data: errors }),
     {name: 'Warnings'}.merge({ data: warnings }),
     {name: 'Info'}.merge({ data: info })]
  end

  def badness_chart_data
    [{name: 'Badness'}.merge({ data: badness })]
  end

  private

  def badness
    threshold_filter = lambda { |key, value| raw_data[:errors][key] > 0 }
    raw_data[:badness].select(&threshold_filter).sort { |r|
      k,_v = r
      raw_data[:badness][k]
    }.to_h
  end
end
