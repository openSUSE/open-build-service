class AssignmentsController < ApplicationController
  before_action :set_project, only: :index
  before_action :set_package, only: %i[create destroy]
  before_action :set_assignee, only: :create

  # GET /assignments/projects/:project_name
  def index
    assignments = @project.assignments

    render 'assignments/index', locals: { assignments: assignments, project: @project }, formats: [:xml]
  end

  # POST /assignments/projects/:project_name/packages/:package_name
  def create
    @assignment = Assignment.new(assigner: User.session, assignee: @assignee, package: @package)

    if @assignment.save
      render_ok
    else
      render_error message: @assignment.errors.full_messages.to_sentence,
                   status: 400, errorcode: 'invalid_assignment'
    end
  end

  # DELETE /assignments/projects/:project_name/packages/:package_name
  def destroy
    @assignment = @package.assignment
    if @assignment.blank?
      render_error status: 404, message: "The package isn't assigned."
      return
    end

    @assignment.destroy

    render_ok
  end

  private

  def set_project
    @project = Project.get_by_name(params[:project_name])
  end

  def set_package
    @package = Package.get_by_project_and_name(params[:project_name], params[:package_name])
  end

  def set_assignee
    request_body = request.body.read
    assignee_xml = if request_body.present?
                     Suse::Validator.validate(:assignment, request_body)
                     Nokogiri::XML(request_body, &:strict).xpath('//assignment/assignee').text
                   end
    @assignee = if assignee_xml.present?
                  User.find_by(login: assignee_xml)
                else
                  User.session
                end
  end
end
