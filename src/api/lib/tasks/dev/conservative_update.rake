require 'bundler'
require 'open3'

namespace :dev do
  desc 'Reset the lockfile to a base ref and conservatively update one gem (default base: origin/master)'
  task :conservative_update, %i[gem base_ref] => :development_environment do |_task, args|
    abort 'Usage: rake "dev:conservative_update[gem,base_ref]"' unless args[:gem]&.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)

    args.with_defaults(base_ref: 'origin/master')

    Dir.chdir(File.expand_path('../../..', __dir__)) do
      output, status = Open3.capture2('git', 'status', '--porcelain', '--', 'Gemfile.lock')
      abort 'Could not check the lockfile status.' unless status.success?
      abort 'Gemfile.lock has local changes. Commit or stash them before running this task.' unless output.empty?

      sh 'git', 'restore', '--source', args[:base_ref], '--worktree', '--', 'Gemfile.lock'
      Bundler.with_unbundled_env do
        sh 'bundle', 'update', '--conservative', args[:gem]
      end

      puts 'Conservative update complete. Review Gemfile.lock before committing and pushing.'
    end
  end
end
