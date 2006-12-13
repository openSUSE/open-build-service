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
  
  def list_tags
    @tag_pages, @tags = paginate :tags, :per_page => 10
  end
  
  def new_tag
    Tag.new
  end

  def create_tag
    @tag = Tag.new(params[:tag])
    if @tag.save
      flash[:notice] = 'Tag was successfully created.'
      redirect_to :action => 'list_tags'
    else
      render :action => 'new_tag'
    end
  end

  def show_tag
    @tag = Tag.find(params[:id])
    @tagged_items = @tag.db_projects
    rescue
      invalid_tag
  end

  def edit_tag
    @tag = Tag.find(params[:id])
    rescue
    invalid_tag
  end
  
  def update_tag
    @tag = Tag.find(params[:id])
    if @tag.update_attributes(params[:tag])
      flash[:note] = 'Tag was successfully updated.'
      redirect_to :action => 'show_tag', :id => @tag
    else
      render :action => 'edit_tag'
    end
  end
  
  def destroy_tag
    Tag.find(params[:id]).destroy
    redirect_to :action => 'list_tags'
  end
  
  
  def invalid_tag
    logger.error("Attempt to access invalid tag #{params[:id]}")
    flash[:note] = 'Invalid tag'
    redirect_to :action => 'list_tags'
  end
  
  
end
