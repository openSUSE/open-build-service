require File.dirname(__FILE__) + '/activexml.rb'
require 'models/bs_request'

class BsRequest < ActiveXML::Base

  def self.find( *args )
    self.fake_find( 'bs_requests', *args )
  end

  def self.from_value( value )
    return BsRequest.new(value)
  end
end

