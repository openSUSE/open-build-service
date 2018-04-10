# frozen_string_literal: true
class IssuesController < ApplicationController
  before_action :require_admin, only: [:create, :update, :destroy]

  def show
    required_parameters :id, :issue_tracker_id

    # NOTE: issue_tracker_id is here actually the name
    issue = Issue.find_or_create_by_name_and_tracker(params[:id], params[:issue_tracker_id], params[:force_update])

    render xml: issue.render_axml
  end
end
