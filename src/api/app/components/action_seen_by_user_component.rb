class ActionSeenByUserComponent < ApplicationComponent
  def initialize(action:, user:, render_only: false)
    super

    @action = action
    @user = user
    @render_only = render_only
  end

  def seen_by_user
    @action.seen_by_users.exists?({ id: @user.id })
  end
end
