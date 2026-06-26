class Webui::SessionController < Webui::WebuiController
  # We are signing up people, can't require them to login
  skip_before_action :extract_user, :check_anonymous_access

  def create
    user = User.find_with_credentials(params.fetch(:username, ''), params.fetch(:password, ''))

    if user
      session[:login] = user.login
      # Redirect to user_path instead of back to new_session_path...
      request.env['HTTP_REFERER'] = nil if request.referer.to_s.end_with?(new_session_path)

      redirect_back_or_to(user_path(user), allow_other_host: false)
    else
      redirect_back_or_to(root_path, error: 'Authentication Failed', allow_other_host: false)
    end
  end

  def reset
    reset_session

    redirect_to root_path
  end
end
