class MonitorController < ApplicationController


  def index
    get_settings
    if request.post? && ! params[:project].nil?
      redirect_to :project => params[:project]
    else
      @workerstatus = Workerstatus.find :all
    end
  end


  def filtered_list
    get_settings
    @workerstatus = Workerstatus.find :all
    render :partial => 'building_table'
  end


  def get_settings
    @project_filter = params[:project]

    # @interval_steps must be > 0:
    # @interval_steps * @max_color + @dead_line minutes
    @interval_steps = 1
    @max_color = 240
    @time_now = Time.now
    @dead_line = 1.hours.ago
  end

end
