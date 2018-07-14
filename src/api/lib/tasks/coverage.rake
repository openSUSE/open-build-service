namespace :ci do
  desc 'Generate merged coverage report'
  task :simplecov_ci_merge do
    require 'simplecov'
    require 'codecov'
    require 'coveralls'

    # initialize data members
    # and configure simplecov
    coverage_results = []
    SimpleCov.filters.clear

    base_dir = Rails.root.join('coverage_results')
    Dir["#{base_dir}/resultset*.json"].each do |file|
      # load json results from coverage folder
      file_results = JSON.parse(File.read(file))

      # parse results from coverage file to array
      file_results.each do |command, data|
        result = SimpleCov::Result.from_hash(command => data)
        coverage_results << result
      end
    end

    # merge results from array to results object
    merged_results = SimpleCov::ResultMerger.merge_results(*coverage_results)

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
      Coveralls::SimpleCov::Formatter,
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Codecov
    ]
    merged_results.format!
  end
end
