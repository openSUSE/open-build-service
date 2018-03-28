require 'xmlhash'
module Person
  class TokenController < ApplicationController
    before_action :set_user

    # GET /person/<login>/token
    def index
      authorize @user, :show?

      @list = @user.service_tokens
    end

    # POST /person/<login>/token
    def create
      authorize @user, :update?

      pkg = nil
      if params[:project] || params[:package]
        pkg = Package.get_by_project_and_name(params[:project], params[:package])
      end
      @token = Token::Service.create(user: @user, package: pkg)
    end

    # DELETE /person/<login>/token/<id>
    def delete
      authorize @user, :update?

      token = Token::Service.where(user_id: @user.id, id: params[:id]).first

      render_error status: 404 && return unless token

      token.destroy
      render_ok
    end

    private

    def set_user
      @user = User.find_by(login: params[:login])
    end
  end
end
