require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'find'
require 'tempfile'

RAILS_BASE_DIRS = ['app', 'db', 'config', 'lib', 'test'].map{|dir| Rails.root.join(dir) }

class CodeQualityTest < ActiveSupport::TestCase
  def setup
    @ruby_files = []
    RAILS_BASE_DIRS.each do |base_dir|
      Find.find(base_dir) do |path|
        @ruby_files << path if FileTest.file?(path) and path.end_with?('.rb')
      end
    end
  end

  # Does a static syntax check, but doesn't interpret the code
  test "static ruby syntax" do
    # fast test first
    tmpfile = Tempfile.new('output')
    tmpfile.close
    IO.popen("ruby -cv - 2>&1 > /dev/null | grep '^-' > #{tmpfile.path}", "w") do |io|
      io.write("# encoding: utf-8\n")
      @ruby_files.each do |ruby_file|  
        lines = File.open(ruby_file).read 
        begin
          io.write(lines)
          io.write("\n")
        rescue Errno::EPIPE
        end
      end
    end
    tmpfile.open
    line = tmpfile.read
    tmpfile.close
    return if line.empty?
    puts "ruby -cv gave output: testing syntax of each ruby file... #{line}"
    @ruby_files.each do |ruby_file|
      IO.popen("ruby -cv #{ruby_file} 2>&1 > /dev/null | grep #{Rails.root}") do |io|
        line = io.read
        unless line.empty?
          puts line
          assert(false, "ruby -cv #{ruby_file} gave output\n#{line}")
        end
      end
    end
    puts "done"
  end

  # Checks that no 'debugger' statement is present in ruby code
  test "no ruby debugger statement" do
    @ruby_files.each do |ruby_file|
      File.open(ruby_file).each_with_index do |line, number|
        assert(false, "#{ruby_file}:#{number + 1} 'debugger' statement found!") if line.match(/^\s*debugger/)
      end
    end
  end

  test "code complexity" do
    require "flog_cli"
    flog = Flog.new :continue => true
    dirs = %w(app/controllers app/views app/models app/mixins app/indices app/helpers)
    files = FlogCLI.expand_dirs_to_files(*dirs)
    flog.flog(*files)

    score = flog.average
    Current_Score = 24.29
    assert_operator score, :<=, Current_Score + 0.005
      
    if score < Current_Score - 0.01
      puts "Update Current_Score - we're at #{score}" 
    end
  end
end
