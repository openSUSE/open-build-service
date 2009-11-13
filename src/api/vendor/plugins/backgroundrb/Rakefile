require 'rake'
require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'rake/contrib/sshpublisher'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the backgroundrb plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
end

desc "Run all specs"
Spec::Rake::SpecTask.new('specs') do |t|
  t.spec_opts = ["--format", "specdoc"]
  t.libs = ['lib', 'server/lib' ]
  t.spec_files = FileList['specs/**/*_spec.rb']
end

desc "RCov"
task :rcov do
  sh("rcov test/**/*.rb")
end

desc 'Generate documentation for the backgroundrb plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc/output/manual'
  rdoc.title    = 'Backgroundrb'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('LICENSE')
  rdoc.rdoc_files.include('lib/*.rb')
  rdoc.rdoc_files.include('lib/backgroundrb/*.rb')
  rdoc.rdoc_files.include('server/*.rb')
  rdoc.rdoc_files.include('server/lib/*.rb')
  rdoc.template = 'jamis'
end

module Rake
  class BackgrounDRbPublisher <  SshDirPublisher
    attr_reader :project, :proj_id, :user
    def initialize(projname, user)
      super(
            "#{user}@rubyforge.org",
            "/var/www/gforge-projects/backgroundrb",
            "doc/output")
    end
  end
end

desc "Publish documentation to Rubyforge"
task :publish_rdoc => [:rdoc] do
  user = ENV['RUBYFORGE_USER']
  publisher = Rake::BackgrounDRbPublisher.new('backgroundrb', user)
  publisher.upload
end

namespace :git do
  def current_branch
    branches = `git branch`
    return branches.split("\n").detect {|x| x =~ /^\*/}.split(' ')[1]
  end

  desc "Push changes to central git repo"
  task :push do
    sh("git push origin master")
  end

  desc "update master branch"
  task :up do
    t_branch = current_branch
    sh("git checkout master")
    sh("git pull")
    sh("git checkout #{t_branch}")
  end

  desc "rebase current branch to master"
  task :rebase => [:up] do
    sh("git rebase master")
  end

  desc "merge current branch to master"
  task :merge => [:up] do
    t_branch = current_branch
    sh("git checkout master")
    sh("git merge #{t_branch}")
    sh("git checkout #{t_branch}")
  end

  desc "commot current branch"
  task :commit => [:merge] do
    t_branch = current_branch
    sh("git checkout master")
    sh("git push origin master")
    sh("git checkout #{t_branch}")
  end
end

