class IssuesController < ApplicationController
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :destroy]

  def show
    @issue_tracker = IssueTracker.find_by_name(params[:issue_tracker_id])
    unless @issue_tracker
      render_error :status => 404, :errorcode => "not_found", :message => "Unable to find issue tracker '#{params[:issue_tracker]}'" and return
    end
    unless params[:id]
      render_error :status => 400, :errorcode => "missing_parameter", :message => "Please provide an issue parameter" and return
    end
    #render :json => @issue_tracker.issue(params[:id])
    respond_to do |format|
      format.xml  { render :xml => @issue_tracker.issue(params[:id]).to_xml }
      format.json { render :json => @issue_tracker.issue(params[:id]).to_json }
    end
  end
end
