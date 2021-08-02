class Token::WorkflowPolicy < TokenPolicy
  # TODO: remove the second half of the condition when `trigger_workflow` feature is rolled out
  def trigger?
    user.is_active? && Flipper.enabled?(:trigger_workflow, user)
  end
end
