SimpleCov.merge_timeout 3600

class SimpleCovMergedFormatter
  def format(result)
    if ENV["DO_COVERAGE"] == "rcov"
      SimpleCov::Formatter::RcovFormatter.new.format(result)
    else
      SimpleCov::Formatter::HTMLFormatter.new.format(result)
    end
  end
end

SimpleCov.formatter = SimpleCovMergedFormatter

SimpleCov.at_exit do
  puts "Coverage done"
  SimpleCov.result.format!
end

