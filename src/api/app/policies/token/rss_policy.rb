class Token::RssPolicy < TokenPolicy
  # TODO: when trigger_workflow is rolled out, remove the create? method
  def create?
    user == record.user
  end
end
