# typed: false
module Webui
  module Groups
    class UsersController < WebuiController
      before_action :set_group
      before_action :set_user, except: :create
      after_action :verify_authorized

      def create
        authorize @group, :update?

        user = User.find_by(login: params[:user_login])
        if user.nil?
          flash[:error] = "User '#{params[:user_login]}' not found"
          redirect_to group_show_path(@group)
          return
        end

        group_user = GroupsUser.create(user: user, group: @group)
        if group_user.valid?
          flash[:success] = "Added user '#{user}' to group '#{@group}'"
        else
          flash[:error] = "Couldn't add user '#{user}' to group '#{@group}': #{group_user.errors.full_messages.to_sentence}"
        end

        redirect_to group_show_path(@group)
      end

      def destroy
        authorize @group, :update?

        if @group.remove_user(@user)
          flash.now[:success] = "Removed user from group '#{@group}'"
          render 'webui2/webui/webui/flash', status: :ok
        else
          render 'webui2/webui/webui/flash', status: :bad_request
        end
      end

      def update
        authorize @group, :update?

        # In the UI we have multiple "maintainer" checkboxes. They need to have different ids and names
        # to avoid conflicting html ids.
        if params['maintainer'] == 'true'
          # FIXME: This should be an attribute of GroupsUser
          group_maintainer = GroupMaintainer.create(user: @user, group: @group)
          if group_maintainer.valid?
            flash.now[:success] = "Gave maintainer rights to '#{@user}'"
            render 'webui2/webui/webui/flash', status: :ok
          else
            flash.now[:error] = "Couldn't make user '#{user}' maintainer: #{group_maintainer.errors.full_messages.to_sentence}"
            render 'webui2/webui/webui/flash', status: :bad_request
          end
        else
          @group.group_maintainers.where(user: @user).destroy_all
          flash.now[:success] = "Removed maintainer rights from '#{@user}'"
          render 'webui2/webui/webui/flash', status: :ok
        end
      end

      private

      def set_group
        @group = Group.find_by(title: params[:group_title])
        return if @group

        flash.now[:error] = "Group '#{params[:group_title]}' not found"
        render 'webui2/webui/webui/flash', status: :not_found
      end

      def set_user
        @user = @group.users.find_by(login: params[:user_login])
        return if @user

        flash.now[:error] = "User '#{params[:user_login]}' not found in group '#{@group}'"
        render 'webui2/webui/webui/flash', status: :not_found
      end
    end
  end
end
