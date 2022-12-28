class ExcludedRequestDatatable < Datatable
  def_delegators :@view, :link_to, :excluded_request_path, :tag, :request_show_path

  def initialize(params, opts = {})
    @staging_workflow = opts[:staging_workflow]
    @current_user = opts[:current_user]
    @policy_update = Staging::RequestExclusionPolicy.new(@current_user, @staging_workflow).create?
    super
  end

  def view_columns
    @view_columns ||= {
      request: { source: 'BsRequestAction.target_package', cond: :like },
      description: { source: 'Staging::RequestExclusion.description', cond: :like },
      actions: {}
    }
  end

  def data
    records.map do |record|
      {
        request: link_to(record.bs_request.first_target_package, request_show_path(record.bs_request.number)),
        description: record.description,
        actions: process_policy(record)
      }
    end
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @staging_workflow.request_exclusions.includes(bs_request: :bs_request_actions).references(:bs_request).distinct
  end
  # rubocop:enable Naming/AccessorMethodName

  # rubocop:disable Rails/OutputSafety
  def process_policy(excluded_request)
    @policy_update ? link_to_delete(excluded_request).html_safe : ''
  end
  # rubocop:enable Rails/OutputSafety

  def link_to_delete(request_exclusion)
    link_to('#', title: 'Include back this request?', data: { 'bs-toggle': 'modal', 'bs-target': '#delete-excluded-request-modal',
                                                              action: excluded_request_path(@staging_workflow.project, request_exclusion) }) do
      tag.i(nil, class: 'fas fa-times-circle text-danger')
    end
  end
end
