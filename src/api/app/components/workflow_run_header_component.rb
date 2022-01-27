class WorkflowRunHeaderComponent < WorkflowRunRowComponent
  def initialize(workflow_run:)
    super

    @workflow_run = workflow_run
  end

  def status_class
    case status
    when 'fail'
      'badge-danger'
    when 'success'
      'badge-primary'
    else
      'badge-warning'
    end
  end
end
