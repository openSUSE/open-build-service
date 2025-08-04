class ChartComponent < ApplicationComponent
  attr_reader :raw_data

  # parameters to decide whether the column_chart will be displayed or the simplified version will
  MINIMUM_DISTINCT_BUILD_REPOSITORIES = 5
  MINIMUM_BUILD_RESULTS = 12

  def initialize(raw_data:)
    super

    @raw_data = raw_data.reject { |result| Buildresult.new(result[:status]).refused_status? }
  end

  def chart_data
    success = Hash.new(0)
    failed = Hash.new(0)
    building = Hash.new(0)

    # reshape data in subsets to feed the chart
    # shape of each dataset: {repository name, build count occurrencies}
    raw_data.each do |result_entry|
      final_status = Buildresult.new(result_entry[:status])
      key = result_entry[:repository]

      if final_status.successful_final_status? # success results
        success[key] += 1
      elsif final_status.unsuccessful_final_status? # failed results
        failed[key] += 1
      elsif final_status.in_progress_status? # in progress results
        building[key] += 1
      end
    end

    # collect all the datasets
    [
      { name: 'Published' }.merge({ data: success }),
      { name: 'Failed' }.merge({ data: failed }),
      { name: 'Building' }.merge({ data: building })
    ]
  end

  def distinct_repositories
    raw_data.pluck(:repository).to_set
  end

  def status_color(status)
    build_result = Buildresult.new(status)
    return 'text-bg-success' if build_result.successful_final_status?
    return 'text-bg-danger' if build_result.unsuccessful_final_status?

    'text-bg-warning' if build_result.in_progress_status?
  end
end
