SimpleCov.merge_timeout 3600

SimpleCov.at_exit do
  puts "Coverage done"
  SimpleCov.result.format!
end

