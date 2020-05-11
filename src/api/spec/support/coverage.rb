# for tracking test coverage
if ENV['CIRCLE_ARTIFACTS']
  dir = File.join(ENV['CIRCLE_ARTIFACTS'], 'coverage')
  SimpleCov.coverage_dir(dir)
end

# SimpleCov configuration
SimpleCov.start 'rails' do
  # NOTE: Keep filters in sync with test/test_helper.rb
  add_filter '/app/indices/'
  add_filter '/lib/templates/'
  add_filter '/lib/memory_debugger.rb'
  add_filter '/lib/memory_dumper.rb'
  merge_timeout 3600
end
