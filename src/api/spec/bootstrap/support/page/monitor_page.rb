# typed: true
module Page
  class MonitorPage
    include Capybara::DSL

    def initialize(filter_name)
      @filter_name = filter_name
    end

    def filter(element)
      find("#project-monitor-#{filter_name}-dropdown").click
      find(:css, "label[for='#{element.parameterize}-checkbox']").click
    end

    def has_column?(column)
      header.has_text?(column)
    end

    def has_row?(row)
      rows.has_text?(row)
    end

    private

    attr_reader :filter_name

    def rows
      find('table#project-monitor-table')
    end

    def header
      find('.dataTables_scrollHead')
    end
  end
end
