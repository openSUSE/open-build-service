require "rubygems"
require "mocha"
require "test/spec"
require "active_record"
require "active_support"
require "yaml"
require "erb"

class BDRB_CONFIG
  @config_value = {}
  def self.fuck
    @config_value
  end
  def self.set hash
    @config_value = hash
  end
  def self.[] key
    @config_value[key]
  end
end

RAILS_HOME = File.expand_path(File.join(File.dirname(__FILE__) + "/../../../..")) unless defined?(RAILS_HOME)
PACKET_APP = RAILS_HOME + "/vendor/plugins/backgroundrb" unless defined?(PACKET_APP)
WORKER_ROOT = RAILS_HOME + "/vendor/plugins/backgroundrb/test/workers" unless defined?(WORKER_ROOT)
SERVER_LOGGER = RAILS_HOME + "/log/backgroundrb_debug.log" unless defined?(SERVER_LOGGER)

["server","server/lib","lib","lib/backgroundrb"].each { |x| $LOAD_PATH.unshift(PACKET_APP + "/#{x}")}
$LOAD_PATH.unshift(WORKER_ROOT)

require "packet"
require "bdrb_config"

require "backgroundrb_server"


