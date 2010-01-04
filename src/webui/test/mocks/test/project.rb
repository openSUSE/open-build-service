require File.dirname(__FILE__) + '/activexml.rb'
require 'models/project'

class Project < ActiveXML::Base

  def self.find( *args )
    self.fake_find( 'projects', *args )
  end

  def self.from_value( value, opt )
    return Project.new(value, opt)
  end
end

