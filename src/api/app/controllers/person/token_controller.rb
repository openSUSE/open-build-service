# typed: false
require 'xmlhash'
module Person
  class TokenController < ApplicationController
    before_action :set_user

    # GET /person/<login>/token
    def index
      authorize @user, :show?

      @list = @user.tokens
    end

    # POST /person/<login>/token
    def create
      authorize @user, :update?

      pkg = if params[:project] || params[:package]
              Package.get_by_project_and_name(params[:project], params[:package])
            end

      @token = Token.token_type(params[:operation]).create(user: @user, package: pkg)
    end

    # DELETE /person/<login>/token/<id>
    def delete
      authorize @user, :update?

      token = @user.tokens.find(params[:id])

      render_error status: 404 && return unless token

      token.destroy
      render_ok
    end

    private

    def set_user
      @user = User.find_by(login: params[:login]) || User.find_nobody!
    end
  end
end
