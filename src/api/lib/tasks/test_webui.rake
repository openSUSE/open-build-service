
Rake::TestTask.new do |t|
  t.libs << "test"
  test_files = FileList['test/unit/*_test.rb'].exclude(%r{webui})
  test_files += FileList['test/models/*_test.rb'].exclude(%r{webui})
  test_files += FileList['test/**/*_test.rb'].exclude(%r{webui}).exclude(%r{test/models}).exclude(%r{test/unit})
  t.test_files = test_files
  t.name = 'test:api'
end

filelist = FileList.new

FileList['test/**/*_test.rb'].each do |f|
  next if f !~ %r{webui}
  filelist << f
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = filelist
  t.name = 'test:webui'
end

