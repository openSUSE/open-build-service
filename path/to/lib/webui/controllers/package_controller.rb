# frozen_string_literal: true

require 'ostruct'

class Webui::PackageController
  def users
    @package = Package.find(params[:id])
    @users = @package.users.includes(:role).where(role: { name: 'maintainer' })

    if @package.develpackage?
      @users = @users.or(Package.where(develpackage: true).includes(:role).where(role: { name: 'maintainer' }))
    end

    @users = @users.includes(:role).order(:name)
    render json: @users
  end
end