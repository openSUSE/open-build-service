
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb'].exclude(%r{webui})
  t.name = 'test:api'
end

filelist = FileList['test/**/*_test.rb']
filelist1 = FileList.new
filelist2 = FileList.new

filelist.each do |f|
  next if f !~ %r{webui}
  if f =~ %r{/(models|helpers|unit)/}
    filelist1 << f
    next
  end
  if f =~ %r{spider} # the most expensive one is extra
    next
  end
  if f =~ %r{project|attribute|package}
    filelist2 << f
    next
  end
  filelist1 << f
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = filelist1
  t.name = 'test:webui1'
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = filelist2
  t.name = 'test:webui2'
end

