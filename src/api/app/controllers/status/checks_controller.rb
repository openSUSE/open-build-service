class Status::ChecksController < ApplicationController
  before_action :require_checkable, only: [:index, :show, :destroy, :update]
  before_action :require_or_create_checkable, only: :create
  before_action :require_check, only: [:show, :destroy, :update]
  before_action :set_xml_check, only: [:create, :update]
  skip_before_action :require_login, only: [:show, :index]
  after_action :verify_authorized

  def index
    @checks = @checkable.checks
    authorize @checks
  end

  def show
    authorize @check
  end

  def create
    @xml_check[:checkable] = @checkable
    @check = Status::Check.new(@xml_check)
    authorize @check
    if @check.save
      render :show
    else
      render_error(status: 422, errorcode: 'whatever', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  def update
    authorize @check
    if @check.update(@xml_check)
      render :show
    else
      render_error(status: 422, errorcode: 'whatever', message: "Could not save check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  def destroy
    authorize @check
    if @check.destroy
      render_ok
    else
      render_error(status: 422, errorcode: 'whatever', message: "Could not delete check: #{@check.errors.full_messages.to_sentence}")
    end
  end

  private

  def require_or_create_checkable
    project = Project.get_by_name(params[:project_name])
    repository = project.repositories.find_by!(name: params[:repository_name])
    @checkable = repository.status_publishes.find_or_create_by(build_id: params[:status_repository_publish_build_id])
  end

  def require_checkable
    @checkable = Status::RepositoryPublish.find_by(build_id: params[:status_repository_publish_build_id]) if params[:status_repository_publish_build_id]
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find status_repository_publish with id '#{params[:status_repository_publish]}'") unless @checkable
  end

  def require_check
    @check = @checkable.checks.find_by(id: params[:id])
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find check with id '#{params[:id]}'") unless @check
  end

  def set_xml_check
    @xml_check = xml_hash
    return if @xml_check.present?
    render_error status: 404, errorcode: 'empty_body', message: 'Request body is empty!'
  end

  def xml_hash
    result = (Xmlhash.parse(request.body.read) || {}).with_indifferent_access
    result.slice(:url, :state, :short_description, :name)
  end
end
