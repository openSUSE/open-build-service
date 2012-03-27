#!/usr/bin/env ruby
require 'rubygems'
require 'headless'
require 'colored'
require 'net/http'

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

PORT=3199

if true
frontend = Thread.new do
  puts "Starting test webui at port #{PORT} ..."
  webui_out = IO.popen("cd ../webui; exec ./script/server -e test -p #{PORT} 2>&1")
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
    rescue IOError
      break
    end
  end
end

while true
  puts "Waiting for Webui to serve requests..."
  begin
    Net::HTTP.start("localhost", PORT) do |http|
      http.open_timeout = 15
      http.read_timeout = 15
      # we need to ask for something that is available without login _and_ starts api and backend too
      res = http.get('/main/startme')
      case res
        when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPUnauthorized
          # OK
        else
          puts "Webui did not response nicely"
          Process.kill "INT", webui_out.pid
          webui_out.close
          webui_out = nil
          frontend.join
          exit 1
      end
    end
  rescue Errno::ECONNREFUSED, Errno::ENETUNREACH, Timeout::Error
    sleep 1
    next
  end
  break
end
end

puts "Webui ready"
$data[:url] = "http://localhost:#{PORT}"
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


# Prepare folders and variables needed for the run
Dir.mkdir $data[:report_path] unless File.exists? $data[:report_path]
report = HtmlReport.new
fail_details = String.new
passed  = 0
failed  = 0
skipped = 0
TestRunner.add_all
tests = [ "login_as_user",
          "login_as_second_user",
          "login_as_admin",
          "login_invalid_entry",
          "login_empty_entry",
          "login_from_search",
          "login_from_all_projects",
          "login_from_status_monitor",
          "change_real_name_for_user",
          "create_home_project_for_user",
          "create_home_project_for_second_user",
          "create_subproject_for_user",
          "create_home_project_for_admin",
          "create_subproject_without_name",
          "create_subproject_name_with_spaces",
          "create_subproject_with_only_name",
          "create_subproject_with_long_description",
          "create_subproject_duplicate_name",
          "create_global_project",
          "create_global_project_as_user",
          "switch_home_project_tabs",
          "change_home_project_title",
          "change_home_project_description",
          "change_home_project_info",
          "switch_subproject_tabs",
          "change_subproject_title",
          "change_subproject_description",
          "change_subproject_info",
          "switch_global_project_tabs",
          "change_global_project_title",
          "change_global_project_description",
          "change_global_project_info",
          "add_all_permited_project_attributes_for_user",
          "add_all_permited_project_attributes_for_second_user",
          "add_all_not_permited_project_attributes_for_user",
          "add_invalid_value_for_project_attribute",
          "wrong_number_of_values_for_project_attribute",
          "add_same_project_attribute_twice",
          "add_all_admin_permited_project_attributes",
          "add_all_admin_not_permited_project_attributes",
          "create_package_without_name",
          "create_package_name_with_spaces",
          "add_all_admin_not_permited_package_attributes",
          "search_for_subprojects",
          "search_for_public_projects",
          "search_non_existing_by_name",
          "search_non_existing_by_title",
          "search_non_existing_by_description",
          "search_non_existing_by_attributes",
          "search_for_nothing",
          "search_in_nothing",
          "search_with_empty_text",
          "check_public_projects_list",
          "check_all_projects_list",
          "filter_specific_project",
          "filter_non_global_projects",
          "filter_all_subprojects",
          "filter_all_projects_by_user",
          "filter_non_existing",
          "add_project_maintainer",
          "add_project_bugowner",
          "add_project_reviewer",
          "add_project_downloader",
          "add_project_reader",
          "create_package_without_name", 
          "create_package_name_with_spaces", 
          "create_package_with_only_name", 
          "create_package_with_long_description",
          "add_additional_project_roles_to_a_user",
          "add_all_project_roles_to_admin",
          "add_project_role_to_non_existing_user",
          "add_project_role_with_empty_user_field",
          "add_project_role_to_invalid_username",
          "add_project_role_to_username_with_question_sign",
          "edit_project_user_increase_roles",
          "edit_project_user_reduce_roles",
          "edit_project_user_remove_all_roles",
          "delete_subproject",
          "delete_project_attribute_at_remote_project_as_user",
          "create_home_project_package_for_user",
          "change_home_project_title",
          "remove_user_real_name", 
          "real_name_stays_changed",
          "edit_project_user_add_all_roles"]
#TestRunner.set_limitto ["spider_anonymously"]

# Run the test
display = Headless.new
display.start if display
driver = WebDriver.for :firefox #, :remote , "http://localhost:5910'
#driver.manage.timeouts.implicit_wait = 3 # seconds
$page = WebPage.new driver
time_started = Time.now
TestRunner.run do |test|
  if test.status == :ready then
    print((test.name.to_s+"                                               ")[0,55])
    STDOUT.flush
  else
    puts case(test.status)
      when :pass then
        passed += 1
        test.status.to_s.bold.green
      when :fail then 
        failed += 1
        fail_details += "\n#{failed}) #{test.name}:\n#{test.message}".red
        test.status.to_s.bold.red
      when :skip then
        skipped += 1
        test.status.to_s.bold.blue
      when :rescheduled then
        test.status.to_s.bold.green
      else
        raise 'Invalid status value!'
    end
    report.add test unless test.status == :rescheduled
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
puts fail_details unless ARGV.include? "--no-details"
gets if ARGV.include? "--pause-on-exit"

