class ActionSeenByUserComponent < ApplicationComponent
  def initialize(action:, user:, seen_by_user: nil, render_only: false)
    super

    @action = action
    @user = user
    @render_only = render_only
    @seen_by_user = seen_by_user
    @seen_by_user = @action.seen_by_users.exists?({ id: @user.id }) if @seen_by_user.nil?
  end

  def render_icon_status
    if @seen_by_user
      tag.i(nil, class: 'fa-regular fa-square-check')
    else
      tag.i(nil, class: 'fa-regular fa-square')
    end
  end
end
