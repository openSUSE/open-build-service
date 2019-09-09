class Webui::UsersController < Webui::WebuiController
  before_action :require_login, only: [:index]
  before_action :require_admin, only: [:index]

  def index
    respond_to do |format|
      format.html
      format.json { render json: UserConfigurationDatatable.new(params, view_context: view_context) }
    end
    # TODO: Remove the statement after migration is finished
    switch_to_webui2
  end

  def create
    begin
      UnregisteredUser.register(opts)
    rescue APIError => e
      flash[:error] = e.message
      redirect_back(fallback_location: root_path)
      return
    end

    flash[:success] = "The account '#{params[:login]}' is now active."

    if User.admin_session?
      redirect_to users_path
    else
      session[:login] = opts[:login]
      User.session = User.find_by!(login: session[:login])
      if User.session!.home_project
        redirect_to project_show_path(User.session!.home_project)
      else
        redirect_to root_path
      end
    end
  end

  def new
    @pagetitle = params[:pagetitle] || 'Sign up'
    @submit_btn_text = params[:submit_btn_text] || 'Sign up'
    switch_to_webui2
  end

  private

  def opts
    {
      realname: params[:realname], login: params[:login], state: params[:state],
      password: params[:password], password_confirmation: params[:password_confirmation],
      email: params[:email]
    }
  end
end
