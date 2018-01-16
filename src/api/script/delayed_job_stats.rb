puts '-----------EVENT-STATS------------'
mails_sent = Event::Base.where(mails_sent: false).count
undone_jobs = Event::Base.where.not(undone_jobs: 0).count
puts "There are currently #{mails_sent + undone_jobs} Events to be processed"
puts '---------Events by type-----------'
puts 'Mails to send'.ljust(30) + mails_sent.to_s
puts 'Backend jobs to do'.ljust(30) + undone_jobs.to_s

puts '-------------DJ-STATS-------------'
puts "There are currently #{Delayed::Job.count} jobs in the queues"
puts '-----------Jobs by type-----------'
(::ApplicationJob.subclasses + ::CreateJob.subclasses).each do |dj_name|
  job_count = Delayed::Job.where("handler like '%#{dj_name}%'").count
  puts "#{dj_name.to_s.ljust(30)} #{job_count}" if job_count > 0
end
puts '-----------Jobs by queue----------'
queues = ['quick', 'releasetracking', 'issuetracking', 'mailers', 'default', 'project_log_rotate']
queues.each do |dj_queue|
  job_count = Delayed::Job.where(queue: dj_queue).count
  puts "#{dj_queue.to_s.ljust(30)} #{job_count}" if job_count > 0
end
