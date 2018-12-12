module Webui2::GroupsController
  def webui2_update
    authorize @group, :update?

    user = User.find_by_login(webui2_group_params[:userid])
    if user && @group.add_user(user)
      flash[:success] = "User '#{user}' successfully added to group '#{@group}'."
      redirect_to group_show_path(title: @group) + '#tab-group-members'
    else
      redirect_back(fallback_location: root_path, error: "Group couldn't be updated: #{@group.errors.full_messages.to_sentence}")
    end
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
