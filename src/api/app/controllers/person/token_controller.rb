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

      pkg = (Package.get_by_project_and_name(params[:project], params[:package]) if params[:project] || params[:package])

      @token = Token.token_type(params[:operation]).create(description: params[:description], executor: @user, package: pkg, scm_token: params[:scm_token])
      return if @token.valid?

      render_error status: 400,
                   errorcode: 'invalid_token',
                   message: "Failed to create token: #{@token.errors.full_messages.to_sentence}."
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
