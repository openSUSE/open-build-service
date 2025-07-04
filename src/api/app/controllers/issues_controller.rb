class IssuesController < ApplicationController
  def show
    issue = Issue.find_or_create_by_name_and_tracker(params[:id], params[:issue_tracker_name], params[:force_update])

    render xml: issue.render_axml
  end
end
