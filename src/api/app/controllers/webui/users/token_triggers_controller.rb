class Webui::Users::TokenTriggersController < Webui::WebuiController
  include Pundit
  include Triggerable

  before_action :set_token
  before_action :set_project_name
  before_action :set_package_name
  # From Triggerable
  before_action :set_project, except: [:show]
  before_action :set_package, except: [:show]
  before_action :set_object_to_authorize, except: [:show]
  # set_multibuild_flavor needs to run after the set_object_to_authorize callback
  append_before_action :set_multibuild_flavor, except: [:show]

  rescue_from 'Project::Errors::UnknownObjectError' do |exception|
    flash[:error] = "#{exception.message}"
    redirect_to tokens_url
  end

  rescue_from 'Package::Errors::UnknownObjectError' do |exception|
    flash[:error] = "#{exception.message}"
    redirect_to tokens_url
  end

  def show
    authorize @token, :show?
  end

  def update
    authorize @token, :webui_trigger?

    opts = { project: @project, package: @package, repository: params[:repository], arch: params[:arch] }
    opts[:multibuild_flavor] = @multibuild_container if @multibuild_container.present?

    begin
      @token.call(opts)
      flash[:success] = "Token with id #{@token.id} successfully triggered!"
    rescue Token::Errors::NoReleaseTargetFound, Project::Errors::WritePermissionError => e
      flash[:error] = "Failed to trigger token: #{e.message}"
    rescue Backend::NotFoundError => e
      flash[:error] = "Failed to trigger token: #{e.summary}"
    end

    redirect_to tokens_url
  end

  private

  def set_token
    @token = Token.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] = e.message
    redirect_to tokens_url
  end

  def set_project_name
    @project_name = params[:project]
  end

  def set_package_name
    @package_name = params[:package]
  end
end
