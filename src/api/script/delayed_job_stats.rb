puts "-------------DJ-STATS-------------"
puts "There are currently #{Delayed::Job.count} jobs in the queues"
puts "-----------Jobs by type-----------"
(::ApplicationJob.subclasses + ::CreateJob.subclasses).each do |dj_name|
  job_count = Delayed::Job.where("handler like '%#{dj_name}%'").count
  puts "#{dj_name.to_s.ljust(30)} #{job_count}" if job_count > 0
end
puts "-----------Jobs by queue----------"
queues = %w(quick releasetracking issuetracking mailers default project_log_rotate)
queues.each do |dj_queue|
  job_count = Delayed::Job.where(queue: dj_queue).count
  puts "#{dj_queue.to_s.ljust(30)} #{job_count}" if job_count > 0
end

