class AdminController < ApplicationController

  layout "html"

  def list_sources
    @files = []
    read_dir( "data" )
  end

  hide_action :read_dir
  def read_dir( dir )
    d = Dir.new( dir )
    d.each { |entry|
      if ( entry == "." || entry == ".." )
        next
      end
      path = dir + "/" + entry
      @files.push path
      if File.directory?( path )
        read_dir( path )
      end
    }
  end

  def say_hello
    render( :layout => false )
  end

end
