# see this https://github.com/collectiveidea/delayed_job_active_record/issues/185
# The file got renamed to zzz_* due to this comment:
# https://github.com/collectiveidea/delayed_job_active_record/issues/185#issuecomment-743289981
require 'delayed/backend/active_record'

Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.default_queue_name = 'quick'
# There are too many problems with the optimized SQL for locking jobs,
# it takes about 2 seconds on build.o.o, if there are over 10K jobs.
Delayed::Backend::ActiveRecord.configuration.reserve_sql_strategy = :default_sql
