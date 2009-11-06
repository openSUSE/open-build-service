class MaintenanceController < ApplicationController


  def new

  end

  def index
    redirect_to :action => :released
  end

  def released
    render_static_file "#{RAILS_ROOT}/public/maintenance/released_11.2.html"
  end

  def qa
    render_static_file "#{RAILS_ROOT}/public/maintenance/qa_11.2.html"
  end

  private

  def render_static_file path
    if !File.exist? path or !/^#{RAILS_ROOT}\/public/.match( File.expand_path(path) )
      logger.error "Static file: #{path} not found"
      raise "Static file not found"
    end
    @static_file = path
    render 'static', :locals => {:static_file => path }
  end

end
