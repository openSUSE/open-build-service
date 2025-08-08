class ApplicationComponent < ViewComponent::Base
  # ViewComponent::Base explicitly takes no parameters since
  # https://github.com/ViewComponent/view_component/commit/74fc048f596e9ee5ebb59ce7b45a9ba6cadb9de4
  #
  # A breaking change introduced in 4.0.0
  # https://github.com/ViewComponent/view_component/blob/main/docs/CHANGELOG.md#400
  # "Support compatibility with Dry::Initializer. As a result, EmptyOrInvalidInitializerError will no longer be raised."
  # "Remove default initializer from ViewComponent::Base. Previously, ViewComponent::Base defined a catch-all initializer
  #  that allowed components without an initializer defined to be passed arbitrary arguments."
  def initialize(*_args, **_options)
    super()
  end

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
