class MaintainedProjectDatatable < Datatable
  def_delegator :@view, :link_to
  def_delegator :@view, :project_show_path
  def_delegator :@view, :policy
  def_delegator :@view, :project_maintained_project_path
  def_delegator :@view, :tag

  def initialize(params, opts = {})
    @project = opts[:project]
    @current_user = opts[:current_user]
    @policy_update = ProjectPolicy.new(@current_user, @project).update?
    super
  end

  def view_columns
    @view_columns ||= {
      name: { source: 'Project.name', cond: :like },
      actions: { searchable: false }
    }
  end

  def data
    records.map do |record|
      {
        name: link_to(record.project.name, project_show_path(record.project.name)),
        actions: process_policy(record.project.name)
      }
    end
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @project.maintained_projects.includes(:project)
  end
  # rubocop:enable Naming/AccessorMethodName

  # rubocop:disable Rails/OutputSafety
  def process_policy(project_name)
    @policy_update ? link_to_delete(project_name).html_safe : ''
  end
  # rubocop:enable Rails/OutputSafety

  def link_to_delete(project_name)
    link_to('#', title: 'Delete Project', data: { toggle: 'modal', target: '#delete-maintained-project-modal',
                                                  action: project_maintained_project_path(project_name: @project, maintained_project: project_name) }) do
      tag.i(nil, class: 'fas fa-times-circle text-danger')
    end
  end
end
