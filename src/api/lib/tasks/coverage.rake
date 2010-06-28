namespace :test do

  desc 'Measures test coverage'
  task :coverage do
    rm_f "coverage"
    rm_f "coverage.data"
    rcov = "rcov -Itest --rails --aggregate coverage.data -T -x \" rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*,active_rbac*\""
    system("#{rcov} --html test/unit/*_test.rb test/functional/*_test.rb")
    puts "xdg-open coverage/index.html"
  end

end


