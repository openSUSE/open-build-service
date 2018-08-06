class Status::ChecksController < ApplicationController
  before_action :require_checkable, only: [:index, :show, :destroy]
  before_action :require_or_create_checkable, only: :update
  before_action :require_check, only: [:show, :destroy]

  def index
    @checks = @checkable.checks
  end

  def show; end

  def update
    xml_check = Xmlhash.parse(request.body.read)
    @check = Status::Check.new(checkable: @checkable, url: xml_check['url'], state: xml_check['state'], short_description: xml_check['short_description'], name: xml_check['name'])

    if @check.save
      render :show
    else
      render_error(status: 422, errorcode: 'whatever', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  def destroy; end

  private

  def require_or_create_checkable
    project = Project.get_by_name(params[:project_name])
    if params[:status_repository_publish_build_id]
      repository = project.repositories.find_by!(name: params[:repository_name])
      @checkable = repository.status_publishes.find_or_create_by(build_id: params[:status_repository_publish_build_id])
    elsif params[:log_entry_id]
      # TODO: @checkable = project.project_log_entries.find_or_create(something: params[:log_entry_id])
    end
  end

  def require_checkable
    @checkable = Status::RepositoryPublish.find_by(build_id: params[:status_repository_publish_build_id]) if params[:status_repository_publish_build_id]
    # TODO: @checkable = ProjectLogEntry.find(params[:log_entry_id]) if params[:log_entry_id]
  end

  def require_check
    @check = @checkable.checks.find_by(id: params[:id])
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find check with id '#{params[:id]}'") unless @check
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def check_params
    params.require(:check).permit(:url)
  end
end
