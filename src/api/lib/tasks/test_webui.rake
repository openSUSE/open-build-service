
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb'].exclude(%r{webui})
  t.name = 'test:api'
end

filelist = FileList.new

FileList['test/**/*_test.rb'].each do |f|
  next if f !~ %r{webui}
  if f =~ %r{spider} # the most expensive one is extra
    next
  end
  filelist << f
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/spider_test.rb']
  t.name = 'test:webuispider'
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = filelist
  t.name = 'test:webui'
end

