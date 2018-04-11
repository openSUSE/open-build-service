# frozen_string_literal: true

namespace :test do
  desc 'Measures test coverage'
  task :coverage do
    rm_f 'coverage'
    rm_f 'coverage.data'
    rcov = 'rcov -Itest --rails --aggregate coverage.data -x " rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*,active_rbac*,rbac_helper.rb"'
    system("#{rcov} --no-html test/unit/*_test.rb")
    system("#{rcov} --html -t test/functional/*_test.rb")
    puts 'xdg-open coverage/index.html'
  end

  desc 'Measures test coverage but don\'t display it'
  task :rcov do
    rm_rf 'coverage'
    mkdir 'coverage'
    rcov = 'rcov -Itest --rails --aggregate coverage/aggregate.data -x " rubygems/*,/Library/Ruby/Site/*,gems/*,rcov*,active_rbac*,rbac_helper.rb"'
    system("#{rcov} --html -t test/unit/*_test.rb")
    system("#{rcov} --html -t test/functional/*_test.rb")
  end
end
