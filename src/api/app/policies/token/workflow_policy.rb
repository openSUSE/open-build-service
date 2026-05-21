class Token::WorkflowPolicy < TokenPolicy
  def trigger?
    user.active?
  end
end
