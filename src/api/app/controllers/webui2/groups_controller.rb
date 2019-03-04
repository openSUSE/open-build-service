module Webui2::GroupsController
  def webui2_edit
    authorize @group, :update?

    @roles = Role.global_roles
    @members = @group.users.pluck(:login).join(',')
  end

  def webui2_delete
    authorize @group, :update?

    user = User.find_by_login(params[:user])
    if user && @group.remove_user(user)
      flash[:success] = "User '#{user}' successfully removed from group '#{@group}'."
      redirect_to group_show_path(title: @group) + '#tab-group-members'
    else
      redirect_back(fallback_location: root_path,
                    error: "User '#{user}' couldn't be removed from '#{@group}': #{@group.errors.full_messages.to_sentence}")
    end
  end

  private

  def webui2_group_params
    params.require(:group).permit(:title, :userid)
  end
end
