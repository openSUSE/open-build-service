class Webui::Users::BlockController < Webui::WebuiController
  before_action :check_displayed_user, only: %i[create destroy]
  before_action :set_user_block, only: :destroy

  after_action :verify_authorized

  def create
    @user_block = User.session.user_blocks.new(blocked: @displayed_user)

    authorize @user_block

    if @user_block.save
      flash[:success] = "User '#{@user_block.blocked.login}' was successfully blocked."
    else
      flash[:error] = "Failed to block user: #{@user_block.errors.full_messages.to_sentence}."
    end

    redirect_back_or_to user_path(@displayed_user)
  end

  def destroy
    authorize @user_block

    if @user_block.destroy
      flash[:success] = "User '#{@user_block.blocked.login}' was successfully unblocked."
    else
      flash[:error] = "Failed to unblock user: #{@user_block.errors.full_messages.to_sentence}"
    end

    redirect_back_or_to user_path(@displayed_user)
  end

  private

  def set_user_block
    @user_block = BlockedUser.find_by(blocker: User.session, blocked: @displayed_user)
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_back_or_to user_path(@displayed_user)
  end
end
