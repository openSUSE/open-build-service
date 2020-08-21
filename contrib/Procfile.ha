web: bundle exec rails server -P tmp/pids/server$NODE_NUMBER.pid
delayed: bundle exec script/delayed_job.api.rb run
clock: bundle exec clockworkd --log-dir=log -l -c config/clock.rb run
search: bundle exec rake ts:rt:rebuild NODETACH=true
