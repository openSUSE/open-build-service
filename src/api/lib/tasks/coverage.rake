namespace :test do

  desc 'Measures test coverage'
  task :coverage do
    rm_f "coverage"
    rm_f "coverage.data"
    rcov = "rcov -Itest --rails --aggregate coverage.data -x \" rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*,active_rbac*\""
    system("#{rcov} --no-html test/unit/*_test.rb")
    system("#{rcov} --html -t test/functional/*_test.rb")
    puts "xdg-open coverage/index.html"
  end

end


