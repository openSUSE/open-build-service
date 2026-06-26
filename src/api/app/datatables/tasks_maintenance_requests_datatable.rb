class TasksMaintenanceRequestsDatatable < Datatable
  def_delegators :@view_context, :elide_two, :link_to, :package_show_path, :project_monitor_path, :project_show_path, :safe_join, :tag

  def initialize(current_user:, view_context:)
    @current_user = current_user
    @view_context = view_context
    super
  end

  def view_columns
    @view_columns ||= {
      project: {},
      package: {},
      issues: {},
      actions: { searchable: false }
    }
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @current_user.involved_patchinfos
  end
  # rubocop:enable Naming/AccessorMethodName

  def data
    records.map do |record|
      project_name, package_name = elide_two(record.project.name, record.name, 60)

      {
        project: link_to(project_name, project_show_path(project_name)),
        package: link_to(package_name, package_show_path(project_name, package_name)),
        issues: safe_join(record.issues.map { |issue| link_to(issue.label, issue.url, title: issue.summary) }, ', '),
        actions: link_to(project_monitor_path(record.project, pkgname: record.name)) do
                   tag.i(class: %w[fas fa-heartbeat text-danger], title: 'Monitor')
                 end
      }
    end
  end
end
