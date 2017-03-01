namespace :errbit do
  desc 'Raise an exception, can be used to test erbit setups'
  task :test do
    raise "Runtime error exception to test error handling"
  end
end
