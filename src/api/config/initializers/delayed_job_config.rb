Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.default_queue_name = 'quick'
# There are too many problems with the optimized SQL for locking jobs,
# it takes about 2 seconds on build.o.o, if there are over 10K jobs.
Delayed::Backend::ActiveRecord.configuration.reserve_sql_strategy = :default_sql
