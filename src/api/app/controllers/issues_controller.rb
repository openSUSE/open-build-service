class IssuesController < ApplicationController
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :destroy]

  def show
    # NOTE: issue_tracker_id is here actually the name
    issue = Issue.get_by_name_and_tracker( params[:id], params[:issue_tracker_id] )
    render :text => issue.render_axml, :content_type => 'text/xml'
  end
end
