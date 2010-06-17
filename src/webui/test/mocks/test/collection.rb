require File.dirname(__FILE__) + '/activexml.rb'
require 'models/collection'

class Collection < ActiveXML::Base

  def self.find_priv(cache_time, *args)
    ret = Collection.new '<collection/>'
    # special collections are returned
    if args[0] == :id
      args.shift
      if args[0].kind_of? Hash 
        args = args[0]
        if args[:what] == "project" and args[:predicate] == "not(starts-with(@name,'home:'))"
          ret.add_element 'project', 'name' => "Mono"
          ret.add_element 'project', 'name' => "Mono:Factory"
        end
      end
    end
    return ret
  end

  def self.from_value( value, opt )
    return Collection.new(value, opt)
  end
end

