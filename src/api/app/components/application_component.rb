class ApplicationComponent < ViewComponent::Base
  # To be able to use Pundit policies in view components
  def policy(record)
    Pundit.policy(User.possibly_nobody, record)
  end
end
