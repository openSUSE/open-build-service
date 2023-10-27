RSpec.configure do |config|
  # rubocop:disable Style/GlobalVars
  config.before(:suite) do
    $profiler = MethodProfiler.observe(Project)
  end

  config.after(:suite) do
    puts $profiler.report
  end
  # rubocop:enable Style/GlobalVars
end
