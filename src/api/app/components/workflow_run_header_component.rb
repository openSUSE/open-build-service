class WorkflowRunHeaderComponent < WorkflowRunRowComponent
  def initialize(workflow_run:)
    super

    @workflow_run = workflow_run
  end

  def status_class
    case status
    when 'fail'
      'bg-danger'
    when 'success'
      'bg-primary'
    else
      'bg-warning'
    end
  end
end
