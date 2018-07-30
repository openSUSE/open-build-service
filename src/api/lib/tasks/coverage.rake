namespace :ci do
  def merged_results(glob)
    coverage_results = []
    base_dir = Rails.root.join('coverage_results')
    Dir["#{base_dir}/" + glob].each do |file|
      # load json results from coverage folder
      file_results = JSON.parse(File.read(file))

      # parse results from coverage file to array
      file_results.each do |command, data|
        result = SimpleCov::Result.from_hash(command => data)
        coverage_results << result
      end
    end

    # merge results from array to results object
    SimpleCov::ResultMerger.merge_results(*coverage_results)
  end

  desc 'Generate merged coverage report'
  task :simplecov_ci_merge do
    require 'simplecov'
    require 'codecov'
    require 'coveralls'

    # initialize data members
    # and configure simplecov
    SimpleCov.filters.clear
    SimpleCov.merge_timeout 100_000

    SimpleCov.configure do
      add_group('WebUI') { |file| file.filename =~ %r{webui} && file.filename !~ %r{obs_factory} }
      add_group('Jobs') { |file| file.filename =~ %r{jobs/} }
      add_group('Models') { |file| file.filename =~ %r{models/} && file.filename !~ %r{obs_factory} }
      add_group('Helpers') { |file| file.filename =~ %r{helpers/} && file.filename !~ %r{webui} }
      add_group('API Controllers') { |file| file.filename =~ %r{controllers/} && file.filename !~ %r{webui} }
      add_group('Factory Dashboard') { |file| file.filename =~ %r{obs_factory} }
    end

    # upload the result for all
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                     Coveralls::SimpleCov::Formatter,
                                                                     SimpleCov::Formatter::HTMLFormatter,
                                                                     SimpleCov::Formatter::Codecov
                                                                   ])
    merged_results('resultset*.json').format!

    # render subsets
    SimpleCov.coverage_dir('coverage/rspec')
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
    merged_results('resultset-rspec*.json').format!

    SimpleCov.coverage_dir('coverage/minitest')
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
    merged_results('resultset-minitest*.json').format!
  end
end
