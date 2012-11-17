#!/usr/bin/env ruby
require 'rubygems'
require 'headless'
require 'colored'
require 'net/http'
require 'optparse'
require 'builder'

#$DEBUG = 1;

def distribute(*args)
  length = args.pop
  sum = args.reduce(:+).to_f
  i=0; args.collect! { |e| i+=1; [i, e, length*(e/sum)] }
  err = args.collect { |e| e[2].modulo(1) }.reduce(:+).round
  args.collect! do |e|
    if e[1].nonzero? and e[2] < 1 then
      err -= 1
      [ e[0], e[1], 1 ]
    else e
    end
  end
  if err > 0 then
    args.sort! { |a,b| b[2].modulo(1) <=> a[2].modulo(1) }.collect! do |e|
      if err.nonzero? then err -= 1; [ e[0], e[1], e[2].floor + 1 ] 
      else [ e[0], e[1], e[2].floor ] end
    end
  elsif err < 0 then
    args.sort! { |a,b| a[2].modulo(1) <=> b[2].modulo(1) }.collect! do |e|
      if err.nonzero? and e[2].floor > 1 then err += 1; [ e[0], e[1], e[2].floor - 1 ]  
      else [ e[0], e[1], e[2].floor ] end
    end
  end
  args.sort_by { |e| e[0] }.collect { |e| e[2] }
end



# require all libs and test cases
require File.expand_path File.dirname(__FILE__) + '/lib/AcceptanceTest.rb'
Dir.glob(File.dirname(__FILE__) + "/tests/T*.rb").sort.each do |file|
  require File.expand_path file
end

# Setup all global settings
$data = Hash.new
$data[:report_path] = ENV["OBS_REPORT_DIR"]
unless $data[:report_path]
  dir = $data[:report_path] = 'results' + Time.now.strftime("AcceptanceTest__%m-%d-%Y/")
  FileUtils.rm_r(dir) if File.exists?(dir)
end

dienow = false
trap("INT") { dienow = true }
trap("TERM") { dienow = true }
trap("HUP") { dienow = true }
webui_out = nil
frontend = nil

killthread = Thread.new do
  while !dienow do
    sleep 0.2
  end

  if webui_out
    puts "kill #{webui_out.pid}"
    Process.kill "INT", webui_out.pid
  end
end

at_exit do
  if webui_out
    puts "kill -INT #{webui_out.pid}"
    Process.kill "INT", webui_out.pid
    
    webui_out.close
    webui_out = nil
  end
  frontend.join if frontend
end

DEFAULT_PORT=3199
port=nil

options = { 
  :port => DEFAULT_PORT,
  :headless => true,
  :stop_on_fail => false,
  :pause_on_exit => false,
  :details => true
}

limitto = OptionParser.new do |opts|
  opts.banner = "Usage: run_acceptance_test.rb [-h] [-p PORT] [limit_to....]"

  opts.on('-p', '--port PORT', 'Use webui on this port (start our own if default or 3199)') do |p|
    options[:port] = p.to_i
  end
  
  opts.on('-s', '--show', 'Show the browser instead of running headless') do
    options[:headless] = false
  end

  opts.on('-f', '--stop-on-fail', 'Stop running tests on first failed test') do
    options[:stop_on_fail] = true
  end

  opts.on('--pause-on-exit', 'Wait for user input at the end') do
   options[:pause_on_exit] = true
  end

  opts.on('--no-details', 'Do not output details about errors') do
    options[:details] = false
  end

  opts.on( '-h', '--help', 'Display this screen' ) do
     puts opts
     exit 0
  end
end.parse!

lines = []
outputlines = true
if options[:port] == DEFAULT_PORT
  frontend = Thread.new do
    puts "Starting test webui at port #{options[:port]} ..."
    webui_out = IO.popen("cd ../webui; unset BUNDLE_GEMFILE; exec bundle exec rails server -e test -p #{options[:port]} 2>&1")
    puts "Webui started with PID: #{webui_out.pid}"
    begin
      Process.setpgid webui_out.pid, 0
    rescue Errno::EACCES
      # what to do?
      puts "Could not set group to root"
    end
    while webui_out
      begin
        line = webui_out.gets
	lines << line if outputlines
	if line.nil?
          puts "webui died"
	  puts lines.join()
	  exit 1
	end
      rescue IOError
        break
      end
    end
  end
end

while true
  puts "Waiting for Webui to serve requests..."
  begin
    Net::HTTP.start("localhost", options[:port]) do |http|
      http.open_timeout = 15
      http.read_timeout = 15
      # we need to ask for something that is available without login _and_ starts api and backend too
      res = http.get('/main/startme')
      case res
        when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPUnauthorized
          outputlines = false
          # OK
        else
          puts "Webui did not response nicely"
	  if webui_out
            Process.kill "INT", webui_out.pid
            webui_out.close
	  end
          webui_out = nil
          frontend.join if frontend
	  puts lines.join()
          exit 1
      end
    end
  rescue Errno::ECONNREFUSED, Errno::ENETUNREACH, Timeout::Error
    sleep 1
    next
  end
  break
end

puts "Webui ready"
$data[:url] = "http://localhost:#{options[:port]}"
$data[:asserts_timeout] = 5
$data[:actions_timeout] = 5

for i in 1..9 do
  $data["user#{i}".to_sym]                    = Hash.new
  $data["user#{i}".to_sym][:login]            = "user#{i}"
  $data["user#{i}".to_sym][:password]         = "123456"
  $data["user#{i}".to_sym][:created_projects] = Array.new
end

$data[:admin] = Hash.new
$data[:admin][:login] = 'king'
$data[:admin][:password] = 'sunflower'
$data[:admin][:created_projects] = Array.new

$data[:invalid_user] = Hash.new
$data[:invalid_user][:login] = 'dasdasd'
$data[:invalid_user][:password] = 'dasdsad'

$data[:hero] = Hash.new
$data[:hero][:login] = 'maintenance_coord'
$data[:hero][:password] = 'power'

# Prepare folders and variables needed for the run
Dir.mkdir $data[:report_path] unless File.exists? $data[:report_path]
report = HtmlReport.new
fail_details = String.new
builder = Builder::XmlMarkup.new
passed  = 0
failed  = 0
skipped = 0
TestRunner.add_all
if limitto.length > 0
  TestRunner.set_limitto limitto
end

# Run the test
if options[:headless]
  display = Headless.new
  display.start
end
driver = WebDriver.for :firefox
#driver = WebDriver.for :chrome #, :remote , "http://localhost:5910'
#driver.manage.timeouts.implicit_wait = 3 # seconds
$page = WebPage.new driver
time_started = Time.now
builder.testsuite do
  TestRunner.run(options[:stop_on_fail]) do |test|
    if test.status == :ready then
      print("#{test.name}                                               "[0,55])
      STDOUT.flush
    else
      puts case(test.status)
           when :pass then
             passed += 1
             test.status.to_s.bold.green + " (#{test.runtime})"
           when :fail then 
             failed += 1
             fail_details += "\n#{failed}) #{test.name}:\n#{test.message}".red
             test.status.to_s.bold.red + " (#{test.runtime})"
           when :skip then
             skipped += 1
             test.status.to_s.bold.blue
           when :rescheduled then
             test.status.to_s.bold.green
           else
             raise 'Invalid status value!'
           end
      unless test.status == :rescheduled
        report.add test 
        test.to_xml(builder)
      end
    end
  end
end
time_ended = Time.now
$page.close
display.destroy if display

# Put success rate statistics
lp, lf, ls = distribute passed, failed, skipped, 59
puts  ("_"*59)
print ("_"*lp).on_green
print ("_"*lf).on_red
puts  ("_"*ls).on_blue
puts ""
print "     " + "#{passed} passed".bold.green  + "       "
print           "#{failed} failed".bold.red    + "       "
puts            "#{skipped} skipped".bold.blue

# Put time statistics
duration = time_ended - time_started
if duration.div(60) > 0 then
  total_duration  = "Total duration:  #{duration.div(60)} minutes"
  total_duration += " and #{duration % 60} seconds" if duration % 60 > 0
else
  total_duration  = "Total duration:  #{duration} seconds"
end
puts "Test started at: #{time_started.to_s}"
puts "Test ended at:   #{time_ended.to_s}"
puts total_duration
puts ""

# Save report and display details
report.save $data[:report_path] + "report.html"
puts fail_details if options[:details]
gets if options[:pause_on_exit]

report = File.new $data[:report_path] + "junit-result.xml", "w"
report.write builder.target!
report.close

exit 1 if failed > 0
