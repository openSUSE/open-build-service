class ExcludedRequestDatatable < Datatable
  def_delegators :@view, :link_to, :staging_workflow_excluded_request_path, :content_tag, :request_show_path

  def initialize(params, opts = {})
    @staging_workflow = opts[:staging_workflow]
    @current_user = opts[:current_user]
    @policy_update = Staging::RequestExclusionPolicy.new(@current_user, @staging_workflow).create?
    super
  end

  def view_columns
    @view_columns ||= {
      request: { source: 'BsRequest.number', cond: :like },
      description: { source: 'Staging::RequestExclusion.description', cond: :like }
    }
  end

  def data
    records.map do |record|
      {
        request: link_to(record.bs_request.number, request_show_path(record.bs_request.number)),
        description: record.description,
        actions: process_policy(record)
      }
    end
  end

  # rubocop:disable Naming/AccessorMethodName
  def get_raw_records
    @staging_workflow.request_exclusions.includes(:bs_request)
  end
  # rubocop:enable Naming/AccessorMethodName

  # rubocop:disable Rails/OutputSafety
  def process_policy(excluded_request)
    @policy_update ? link_to_delete(excluded_request).html_safe : ''
  end
  # rubocop:enable Rails/OutputSafety

  def link_to_delete(request_exclusion)
    link_to('#', title: 'Include back this request?', data: { toggle: 'modal', target: '#delete-excluded-request-modal',
                                                              action: staging_workflow_excluded_request_path(@staging_workflow, request_exclusion) }) do
      content_tag(:i, nil, class: 'fas fa-times-circle text-danger')
    end
  end
end
