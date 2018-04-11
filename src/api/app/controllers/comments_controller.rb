# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :find_obj, only: [:index, :create]

  def index
    @comments = @obj.comments.order(:id)
  end

  def create
    @obj.comments.create!(body: request.raw_post, user: User.current, parent_id: params[:parent_id])
    render_ok
  end

  def destroy
    comment = Comment.find params[:id]
    authorize comment, :destroy?
    comment.blank_or_destroy
    render_ok
  end

  protected

  def find_obj
    if params[:project]
      if params[:package]
        @obj = Package.get_by_project_and_name(params[:project], params[:package])
        @header = { project: @obj.project.name, package: @obj.name }
      else
        @obj = Project.get_by_name(params[:project])
        @header = { project: @obj.name }
      end
    elsif params[:request_number]
      @obj = BsRequest.find_by_number!(params[:request_number])
      @header = { request: @obj.number }
    else
      @obj = User.current
      @header = { user: @obj.login }
    end
  end
end
