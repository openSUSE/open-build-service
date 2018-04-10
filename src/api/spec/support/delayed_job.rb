# frozen_string_literal: true
# Disabling the delay on delayed jobs
RSpec.configure do |config|
  config.before do
    Delayed::Worker.delay_jobs = false
  end
end
