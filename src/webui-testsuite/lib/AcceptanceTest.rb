# Require all external libraries
require 'rubygems'
require 'tempfile'
require 'cgi'
require 'selenium-webdriver'

# Require all base AcceptanceTesting classes
require File.expand_path File.dirname(__FILE__) + '/common/ClassDeclarations'
require File.expand_path File.dirname(__FILE__) + '/common/Assertions'
require File.expand_path File.dirname(__FILE__) + '/common/WebDriver'
require File.expand_path File.dirname(__FILE__) + '/common/WebPage'
require File.expand_path File.dirname(__FILE__) + '/common/TestData'
require File.expand_path File.dirname(__FILE__) + '/common/TestCase'
require File.expand_path File.dirname(__FILE__) + '/common/HtmlReport'
require File.expand_path File.dirname(__FILE__) + '/common/TestRunner'

# Require all OBS page classes
Dir.glob(File.dirname(__FILE__) + "/**/*Page.rb").each do |file|
 require File.expand_path file
end
