require File.dirname(__FILE__) + '/activexml.rb'
require 'models/package'

class Package < ActiveXML::Base

  def self.find( *args )
    self.fake_find( 'packages', *args )
  end

  def self.from_value( value, opt )
    return Package.new(value, opt)
  end
end

