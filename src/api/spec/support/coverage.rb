# SimpleCov configuration
SimpleCov.start 'rails' do
  ENV['CODECOV_FLAG'] = ENV['TEST_SUITE']
  # NOTE: Keep filters in sync with test/test_helper.rb
  add_filter '/app/indices/'
  add_filter '/lib/templates/'
  add_filter '/lib/memory_debugger.rb'
  add_filter '/lib/memory_dumper.rb'
  merge_timeout 3600
end
