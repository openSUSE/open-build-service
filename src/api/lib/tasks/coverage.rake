namespace :ci do
  desc 'Generate merged coverage report'
  task :simplecov_ci_merge do
    require 'simplecov'
    require 'simplecov-cobertura'

    SimpleCov.collate(Dir['coverage_results/*.json'], 'rails') do
      formatter SimpleCov::Formatter::MultiFormatter.new([SimpleCov::Formatter::CoberturaFormatter,
                                                          SimpleCov::Formatter::HTMLFormatter])
    end
  end
end
