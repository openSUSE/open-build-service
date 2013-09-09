require 'erb'
require 'open3'
require 'yaml'

task :check_syntax => [:check_ruby, :check_erb, :check_yaml]

task :check_erb do
  (Dir["**/*.erb"] + Dir["**/*.rhtml"]).each do |file|
    next if file.match("vendor/rails")
    Open3.popen3('ruby -c') do |stdin, stdout, stderr|
      stdin.puts(ERB.new(File.read(file), nil, '-').src)
      stdin.close
      error = ((stderr.readline rescue false))
      if error
        puts file + error[1..-1]
      end
      stdout.close rescue false
      stderr.close rescue false
    end
  end
end

task :check_ruby do
  Dir['**/*.rb'].each do |file|
    next if file.match("vendor/rails")
    next if file.match("vendor/plugins/.*/generators/.*/templates")
    Open3.popen3("ruby -c #{file}") do |stdin, stdout, stderr|
      error = ((stderr.readline rescue false))
      puts error if error
      stdin.close rescue false
      stdout.close rescue false
      stderr.close rescue false
    end
  end
end

task :check_yaml do
  Dir['**/*.yml'].each do |file|
    next if file.match("vendor/rails")
    begin
      YAML.load_file(file)
    rescue => e
      puts "#{file}:#{(e.message.match(/on line (\d+)/)[1] + ':') rescue nil} #{e.message}"
    end
  end
end
