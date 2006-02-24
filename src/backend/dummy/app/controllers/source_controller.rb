class SourceController < ApplicationController

  require "dummy_builder"
  
  require_dependency "dummy_builder"

  def initialize
    @basedir = DATA_DIRECTORY + "/source/"
    unless File.exists?( @basedir )
      Dir.mkdir @basedir 
    end
  end

  # show all available projects
  def index
    @datadir = @basedir
    read_dir(@datadir)
  end
  
  # show all available packages
  def packagelist
    project = params[:project]
    @datadir = @basedir + project 
    read_dir(@datadir)
  end
  
  # show all available files for a package
  def filelist
    project = params[:project]
    package = params[:package]
    @datadir = @basedir + project + "/" + package
    read_dir(@datadir)
  end
  
  # show a file of a package
  def file    
    project = params[:project]
    package = params[:package]
    file = params[ :file ]
    mimetype = "application/x-download"
    path = @basedir + project + "/" + package
    read_write_file(path, file, mimetype)
  end
  
  
  # show a file of a package
  def package_meta
    project = params[:project]
    package = params[:package]
    mimetype = "text/xml"
    path = @basedir + project + "/" + package
    read_write_file(path, "/_meta", mimetype)        
  end
  
  
  # show a file of a package
  def project_meta
    project = params[:project]
    mimetype = "text/xml"
    path = @basedir  + project
    read_write_file(path, "/_meta", mimetype)
  end
  
  
  def read_write_file (path, file, mimetype)
    fullpath = path + "/" + file
    if request.get?
      unless File.exists?(fullpath)
        render_error :message => "File not found", :status => 404
      else
        send_file( fullpath, :type => mimetype,
            :disposition => "inline" )
      end
    elsif request.put?
      logger.debug "--> processing put request, path: #{fullpath}"
      directory = File.dirname fullpath
      unless File.exists? directory
            Dir.mkdir directory
      end
      f = File.new( fullpath, "w" )
      f.print request.raw_post
      f.close
      render_text "OK"
      if file == "_meta"
        builder = DummyBuilder.new( project, fullpath )
        builder.build
      end
    end
  end
  
  
  def read_dir (path)
    unless File.exists?(path)
      render_error :message => "File not found", :status => 404
    else
      @entries = Dir.new(path).reject { |e| e =~ /(^\.)|(^_meta)/ }
      render( :template => "source/index" )
    end
  end
  
end
