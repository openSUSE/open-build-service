require 'rake/testtask'

# Everything without "webui" in the file name/path is the API test suite
Rake::TestTask.new do |t|
  t.libs << 'test'
  test_files = FileList['test/unit/*_test.rb']
  test_files += FileList['test/models/*_test.rb']
  test_files += FileList['test/**/*_test.rb'].exclude(%r{webui}).exclude(%r{test/models}).exclude(%r{test/unit})
  t.test_files = test_files
  t.name = 'test:api'
  t.warning = false
end

# minitests are a little fragile when it comes to run out of order
# so we cherry pick some functional tests into group1 that are safe
# to take out of order. Be careful especially to leave build, source,
# maintenance and publish controller test in their order
SAFE_TESTS = [
  'test/functional/about_controller_test.rb',
  'test/functional/architectures_controller_test.rb',
  'test/functional/attributes_test.rb',
  'test/functional/channel_maintenance_test.rb',
  'test/functional/read_permission_test.rb',
  'test/functional/statistics_controller_test.rb',
  'test/functional/comments_controller_test.rb',
  'test/functional/group_request_test.rb',
  'test/functional/group_test.rb',
  'test/functional/person_controller_test.rb',
  'test/functional/message_controller_test.rb',
  'test/functional/request_events_test.rb'
].freeze
Rake::TestTask.new do |t|
  t.libs << 'test'
  files = FileList['test/unit/*_test.rb']
  files.include('test/models/*_test.rb')
  files.include('test/policies/*_test.rb')
  files.include('test/integration/*_test.rb')
  SAFE_TESTS.each do |file|
    files.include(file)
  end
  t.test_files = files
  t.name = 'test:api:group1'
  t.warning = false
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  files = FileList['test/functional/**/*_test.rb'].exclude(%r{spider_test})
  SAFE_TESTS.each do |file|
    files.exclude(file)
  end
  t.test_files = files
  t.name = 'test:api:group2'
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
