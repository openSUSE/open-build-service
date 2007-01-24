class PlatformController < ApplicationController

  def initialize
    @basedir = DATA_DIRECTORY + "/platform/"
    unless File.exists?( @basedir )
      Dir.mkdir @basedir
    end
  end


  def index
    read_dir( @basedir )
  end


  def project
    project = params[ :project ]
    read_dir( @basedir + "/" + project)
  end
  
  
  # state of getting + putting of project platform files unclear
  def repository
  
  end
  
    
  def read_dir (path)
    unless File.exists?(path)
      render_error :message => "File not found", :status => 404
    else
      @entries = Array.new 
      @projects = Dir.new(path).reject { |e| e =~ /(^\.)/ }
      @projects.each do |project|
        @platforms = Dir.new(path + "/" + project).reject { |e| e =~ /(^\.)/ }
        
        @platforms.each do |platform|
          @entries << project + "/" + platform 
        end
      end
      render( :template => "platform/index" )
    end
  end
  
  
  
end
