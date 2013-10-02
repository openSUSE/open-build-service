
filelist = FileList['test/**/*_test.rb'].exclude(%r{test/(models|helpers|unit)/})

Rake::TestTask.new do |t|
  t.libs << "test"
  nf = FileList.new
  filelist.to_a.each do |f|
    nf << f if f =~ %r{webui}
  end
  t.test_files = nf
  t.name = 'test:webui'
  t.verbose = true
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = filelist.exclude(%r{webui})
  t.name = 'test:api'
  t.verbose = true
end

