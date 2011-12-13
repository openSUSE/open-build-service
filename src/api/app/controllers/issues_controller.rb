class IssuesController < ApplicationController
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :destroy]

  def show
    # NOTE: issue_tracker_id is here actually the name
    issue = Issue.get_by_issue_tracker_and_name( params[:issue_tracker_id], params[:id] )
    render :text => issue.render_axml, :content_type => 'text/xml'
  end
end
