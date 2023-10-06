require 'xmlhash'
module Person
  class TokenController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    before_action :set_user

    # GET /person/<login>/token
    def index
      authorize @user, :show?

      @list = @user.tokens
    end

    # POST /person/<login>/token
    def create
      authorize @user, :update?

      set_package

      @token = Token.token_type(params[:operation]).create(description: params[:description], executor: @user, package: @package, scm_token: params[:scm_token])
      return if @token.valid?

      render_error status: 400,
                   errorcode: 'invalid_token',
                   message: "Failed to create token: #{@token.errors.full_messages.to_sentence}."
    end

    # DELETE /person/<login>/token/<id>
    def delete
      authorize @user, :update?

      @user.tokens.find(params[:id]).destroy
      render_ok
    end

    private

    def record_not_found(exception)
      render_error status: 404, message: "Couldn't find Token with 'id'=#{exception.id}"
    end

    def set_user
      @user = User.find_by(login: params[:login]) || User.find_nobody!
    end

    def set_package
      @package = nil
      return unless params[:project] || params[:package]

      raise MissingParameterError, 'The package and project parameters must be provided together.' unless params[:project] && params[:package]

      @package = Package.get_by_project_and_name(params[:project], params[:package])
    end
  end
end
