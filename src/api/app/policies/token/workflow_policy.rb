class Token::WorkflowPolicy < TokenPolicy
  def trigger?
    user.is_active?
  end
end
