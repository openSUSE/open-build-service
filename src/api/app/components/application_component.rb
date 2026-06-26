class ApplicationComponent < ViewComponent::Base
  # To be able to use Pundit policies in view components
  def policy(record)
    # rubocop:disable ViewComponent/AvoidGlobalState
    # Passing a user without changing the method signature would be possible only if all view components calling this method
    # store a user in an instance variable, which we could then rely upon here. This is definitely possible, but it implies
    # refactoring all view components relying on this method.
    Pundit.policy(User.possibly_nobody, record)
    # rubocop:enable ViewComponent/AvoidGlobalState
  end
end
