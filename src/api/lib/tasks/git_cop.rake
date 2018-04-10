# frozen_string_literal: true
desc 'Run Git-cop locally'
task :git_cop do
  puts "\nCopying configuration file into ~/.config/git-cop/configuration.yml"
  sh 'mkdir -p ~/.config/git-cop'
  sh 'cp ../../dist/git-cop_configuration.yml ~/.config/git-cop/configuration.yml'
  puts
  sh 'bundle exec git-cop --police'
end
