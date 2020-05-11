RSpec.configure do |config|
  config.include ModelsAuthentication, type: :job

  # Disabling the delay on delayed jobs
  config.before do
    Delayed::Worker.delay_jobs = false
  end
end
