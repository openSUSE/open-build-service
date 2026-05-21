class CannedResponsesController < ApplicationController
  before_action :set_canned_response, only: %i[show update destroy]
  after_action :verify_authorized, except: :index

  def index
    @canned_responses = User.session.canned_responses.order(:title)
    @count = @canned_responses.size
  end

  def show
    authorize @canned_response
  end

  def create
    xml_body = Xmlhash.parse(request.raw_post)
    @canned_response = User.session.canned_responses.new(xml_body.slice('title', 'content', 'decision_type'))

    authorize @canned_response

    if @canned_response.save
      render :show
    else
      render_error message: @canned_response.errors.full_messages,
                   status: 400, errorcode: 'invalid_canned_response'
    end
  end

  def update
    authorize @canned_response

    xml_body = Xmlhash.parse(request.raw_post)
    @canned_response.assign_attributes(xml_body.slice('title', 'content', 'decision_type'))

    if @canned_response.save
      render :show
    else
      render_error message: @canned_response.errors.full_messages,
                   status: 400, errorcode: 'invalid_canned_response'
    end
  end

  def destroy
    authorize @canned_response

    @canned_response.destroy
    render_ok
  end

  private

  def set_canned_response
    @canned_response = User.session.canned_responses.find(params[:id])
  end
end
