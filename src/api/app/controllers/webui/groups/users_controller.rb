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
          redirect_to group_path(@group)
          return
        end

        group_user = GroupsUser.create(user: user, group: @group)
        if group_user.valid?
          flash[:success] = "Added user '#{user}' to group '#{@group}'"
        else
          flash[:error] = "Couldn't add user '#{user}' to group '#{@group}': #{group_user.errors.full_messages.to_sentence}"
        end

        redirect_to group_path(@group)
      end

      def update
        authorize @group, :update?

        # In the UI we have multiple "maintainer" checkboxes. They need to have different ids and names
        # to avoid conflicting html ids.
        if params['maintainer'].to_s.casecmp?('true')
          # FIXME: This should be an attribute of GroupsUser
          group_maintainer = GroupMaintainer.create(user: @user, group: @group)
          if group_maintainer.valid?
            flash.now[:success] = "Gave maintainer rights to '#{@user}'"
            render 'flash', status: :ok
          else
            flash.now[:error] = "Couldn't make user '#{@user}' maintainer: #{group_maintainer.errors.full_messages.to_sentence}"
            render 'flash', status: :bad_request
          end
        else
          @group.group_maintainers.where(user: @user).destroy_all
          flash.now[:success] = "Removed maintainer rights from '#{@user}'"
          render 'flash', status: :ok
        end
      end

      def destroy
        groups_user = GroupsUser.find_by(group: @group, user: @user)
        authorize groups_user, :destroy?

        if @group.remove_user(@user, user_session_login: User.session.login)
          flash[:success] = "Removed user '#{@user}' from group '#{@group}'"
        else
          flash[:error] = "Couldn't remove user '#{@user}' from group '#{@group}'"
        end

        redirect_to group_path(@group)
      end

      private

      def set_group
        @group = Group.find_by(title: params[:group_title])
        return if @group

        flash.now[:error] = "Group '#{params[:group_title]}' not found"
        render 'flash', status: :not_found
      end

      def set_user
        @user = @group.users.find_by(login: params[:user_login])
        return if @user

        flash.now[:error] = "User '#{params[:user_login]}' not found in group '#{@group}'"
        render 'flash', status: :not_found
      end
    end
  end
end
