class WorkflowRunHeaderComponent < WorkflowRunRowComponent
  def initialize(workflow_run:, token_id:)
    super

    @workflow_run = workflow_run
  end

  def status_class
    case status
    when 'fail'
      'text-bg-danger'
    when 'success'
      'text-bg-primary'
    else
      'text-bg-warning'
    end
  end
end
