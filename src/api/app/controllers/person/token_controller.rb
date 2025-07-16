module Person
  class TokenController < ApplicationController
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

    before_action :set_person
    before_action :set_package, :set_operation_default, only: :create
    before_action :set_token, only: %i[update destroy]
    after_action :verify_authorized, except: :index
    validate_action update: { method: :put, request: :token, response: :status }

    # GET /person/<login>/token
    def index
      if @person != User.session && !User.session.admin?
        render_error status: 403, message: 'Can not list tokens of another person: Requires admin permission.'
      end

      @tokens = Token.where(id: [Token.owned_tokens(@person) + Token.shared_tokens(@person) + Token.group_shared_tokens(@person)])
    end

    # POST /person/<login>/token
    def create
      @token = Token.token_type(params[:operation]).new(description: params[:description],
                                                        executor: @person,
                                                        package: @package,
                                                        scm_token: params[:scm_token])
      authorize @token

      if @token.save
        render_ok
      else
        render_error(status: 400, errorcode: 'invalid_token', message: "Failed to create token: #{@token.errors.full_messages.to_sentence}.")
      end
    end

    # PUT /person/<login>/token/<id>params[:operation]
    def update
      authorize @token

      token_attributes = Xmlhash.parse(request.raw_post)
      token_attributes = token_attributes.slice('enabled', 'description', 'scm_token', 'workflow_configuration_path', 'workflow_configuration_url')

      if @token.update(token_attributes)
        render_ok
      else
        render_error status: 400, errorcode: 'invalid_token_attribute_value', message: token.errors.full_messages.to_sentence
      end
    end

    # DELETE /person/<login>/token/<id>
    def destroy
      authorize @token

      @token.destroy

      render_ok
    end

    private

    def set_person
      @person = User.find_by!(login: params[:login])
    end

    def set_token
      @token = @person.tokens.find(params[:id])
    end

    def set_package
      return unless params[:project] && params[:package]

      @package = Package.get_by_project_and_name(params[:project], params[:package], follow_multibuild: true)
    end

    def set_operation_default
      params[:operation] ||= 'service'
    end

    def record_not_found
      render_error status: 404, message: "Couldn't find User '#{params[:login]}'"
    end
  end
end
