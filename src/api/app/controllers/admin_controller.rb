class AdminController < ApplicationController
  layout "rbac"
   
  def list_blacklist_tags
    
    @tags = BlacklistTag.find(:all)  
    @tags ||= []
    
    @number_of_tags = @tags.size
    
  end
  
  def list_tags
    
    logger.debug "[TAG:] admin list_params order_by: #{session[:column]}"
    
    allowed_order_by_arguments = ['id', 'name' , 'count' , 'created_at']
    allowed_sort_by_arguments = ['ASC', 'DESC']
    
    
    #toggle sort direction
    if session[:column] == params[:column] 
      if session[:sort] == 'ASC' then session[:sort] = 'DESC'  
      else session[:sort] = 'ASC'
      end
    end
    
    session[:column] = params[:column] if params[:column]
    
    
    order_by = (session[:column] ||= 'id')
    sort_by = (session[:sort] ||= 'ASC')
    
    
    unless allowed_order_by_arguments.include? order_by
      raise ArgumentError.new( "unknown argument '#{session[:column]}'" )
    end
    
    unless allowed_sort_by_arguments.include? sort_by
      raise ArgumentError.new( "unknown argument '#{session[:sort]}'" )
    end
    
    logger.debug "[TAG: order_by: #{order_by}"
    
    if order_by == 'count' and sort_by == "ASC"
      tags = Tag.find(:all)
      
      @tags = tags.sort { |x,y| x.count <=> y.count }
      
    elsif order_by == 'count' and sort_by == "DESC"
      tags = Tag.find(:all)
      
      @tags = tags.sort { |x,y| y.count <=> x.count }
      
    else
      
      @tags = Tag.find(:all, :order => order_by + ' ' + sort_by)
      
    end
    
    @number_of_tags, @unused_tags = tags_summary
    
  end
  
  
  def tags_summary
    tags = Tag.find(:all)
    unused_tags = []
    tags.each do |tag|
      unused_tags << tag if tag.count == 0
    end
    logger.debug "[TAG:] Number of tags: #{tags.size} Tags not used: #{unused_tags.size}"
    return tags.size, unused_tags.size
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
  
  
  def new_blacklist_tag
    BlacklistTag.new
  end
  
  
  def create_blacklist_tag
    @tag = BlacklistTag.new(params[:tag])
    if @tag.save
      flash[:notice] = 'Tag was successfully created.'
      redirect_to :action => 'list_blacklist_tags'
    else
      render :action => 'new_blacklist_tag'
    end
  end
  
  
  def show_tag
    @tag = Tag.find(params[:id])
    @tagged_projects = @tag.db_projects.find(:all, :group => 'name')
    @tagged_packages = @tag.db_packages.find(:all, :group => 'name')
  rescue
    invalid_tag
  end
  
  
  def show_blacklist_tag
    @tag = BlacklistTag.find(params[:id])
  rescue
    invalid_tag
  end
  
  
  def edit_tag
    @tag = Tag.find(params[:id])
  rescue
    invalid_tag
  end
  
  
  def edit_blacklist_tag
    @tag = BlacklistTag.find(params[:id])
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
  
  
  def update_blacklist_tag
    @tag = BlacklistTag.find(params[:id])
    if @tag.update_attributes(params[:tag])
      flash[:note] = 'Tag was successfully updated.'
      redirect_to :action => 'show_blacklist_tag', :id => @tag
    else
      render :action => 'edit_blacklist_tag'
    end
  end
  
  
  def destroy_tag
    Tag.find(params[:id]).destroy
    redirect_to :action => 'list_tags'
  end
  
  
  def destroy_blacklist_tag
    BlacklistTag.find(params[:id]).destroy
    redirect_to :action => 'list_blacklist_tags'
  end
  
  
  def move_tag
    begin
      tag = Tag.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      flash[:note] = "No such tag #{params[:id]}"
      redirect_to :action => 'list_tags'
      return 
    end
    BlacklistTag.find_or_create_by_name(tag.name)
    tag.destroy
    flash[:note] = 'Tag was successfully moved.'
    redirect_to :action => 'list_blacklist_tags'
  end
  
  
  def delete_unused_tags
    tags = Tag.find(:all)
    unused_tags = []
    tags.each do |tag|
      unused_tags << tag if tag.count == 0
      
    end
    logger.debug "[TAG:] The following tags will be DELETED: #{unused_tags.inspect}"
    logger.debug "[TAG:] .... NOW!"
    unused_tags.each do |tag|
      tag.destroy
    end
    redirect_to :action => 'list_tags'
  end
  
  
  def invalid_tag
    logger.error("Attempt to access invalid tag #{params[:id]}")
    flash[:error] = "Invalid tag #{params[:id]}"
    redirect_to :action => 'list_tags'
  end
  
  
end
