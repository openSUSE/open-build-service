# frozen_string_literal: true
require 'rake/testtask'

# Everything without "webui" in the file name/path is the API test suite
Rake::TestTask.new do |t|
  t.libs << 'test'
  test_files = FileList['test/unit/*_test.rb'].exclude(%r{webui})
  test_files += FileList['test/models/*_test.rb'].exclude(%r{webui})
  test_files += FileList['test/**/*_test.rb'].exclude(%r{webui}).exclude(%r{test/models}).exclude(%r{test/unit})
  t.test_files = test_files
  t.name = 'test:api'
  t.warning = false
end

# The spider test are in their own test suite to not pollute code coverage measurement.
Rake::TestTask.new do |t|
  t.libs << 'test'
  proxy_mode_files = FileList.new
  t.test_files = proxy_mode_files.include('test/functional/webui/spider_test.rb')
  t.name = 'test:spider'
  t.warning = false
end
