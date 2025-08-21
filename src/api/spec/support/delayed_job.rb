RSpec.configure do |config|
  # Disabling the delay on delayed jobs
  config.before(:example, :perform_active_job) do
    Delayed::Worker.delay_jobs = false
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
  end
end
