require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'find'

RAILS_BASE_PATH = File.dirname(__FILE__) + '/../../'
RAILS_BASE_DIRS = ['app', 'db', 'config', 'lib', 'test', 'vendor/plugins'].map{|dir| RAILS_BASE_PATH + '/' + dir}

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
  def test_static_ruby_syntax
    @ruby_files.each do |ruby_file|
      assert system("ruby -cv #{ruby_file} > /dev/null"), "#{ruby_file} failed ruby -c"
    end
  end

  # Checks that no 'debugger' statement is present in ruby code
  def test_no_ruby_debugger_statement
    @ruby_files.each do |ruby_file|
      File.open(ruby_file).each_with_index do |line, number|
        assert(false, "#{ruby_file}:#{number + 1} 'debugger' statement found!") if line.match(/^\s*debugger/)
      end
    end
  end
end
