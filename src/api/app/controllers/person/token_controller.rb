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
      # TODO: remove when `trigger_workflow` feature is rolled out
      raise(NoPermission, 'You are not allowed to create a workflow token. You need to join the Beta program for that.') if params[:operation] == 'workflow' &&
                                                                                                                            !Flipper.enabled?(:trigger_workflow, @user)

      authorize @user, :update?

      pkg = (Package.get_by_project_and_name(params[:project], params[:package]) if params[:project] || params[:package])

      @token = Token.token_type(params[:operation]).create(user: @user, package: pkg, scm_token: params[:scm_token])
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
