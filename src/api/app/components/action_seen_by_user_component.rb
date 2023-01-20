class ActionSeenByUserComponent < ApplicationComponent
  def initialize(action:, user:)
    super

    @action = action
    @user = user
  end

  def seen_by_user
    @action.seen_by_users.exists?({ id: @user.id })
  end
end
