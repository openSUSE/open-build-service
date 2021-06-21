class DistributionsController < ApplicationController
  before_action :require_admin, except: [:index, :show, :include_remotes]
  before_action :set_body_xml, except: [:index, :show, :include_remotes]

  validate_action bulk_replace: { method: :put, request: :distributions }
  validate_action bulk_replace: { method: :post, request: :distributions }

  validate_action create: { method: :put, request: :distribution }
  validate_action create: { method: :post, request: :distribution }

  validate_action update: { method: :put, request: :distribution }
  validate_action update: { method: :post, request: :distribution }

  # GET /distributions
  def index
    @distributions = Distribution.local

    respond_to do |format|
      format.xml
      format.json { render json: @distributions }
    end
  end

  # GET /distributions/1234
  def show
    @distribution = Distribution.find(params[:id])

    respond_to do |format|
      format.xml
      format.json { render json: @distribution }
    end
  end

  # POST /distributions
  def create
    distribution = Distribution.new_from_xmlhash(@body_xml)

    if distribution.save
      render_ok
    else
      render_error message: distribution.errors.full_messages,
                   status: 400, errorcode: 'invalid_distribution'
    end
  end

  # PATCH/PUT /distributions/1234
  def update
    distribution = Distribution.find(params[:id])
    # We don't allow updating remote distributions
    distribution.readonly! if distribution.remote

    if distribution.update_from_xmlhash(@body_xml)
      render_ok
    else
      render_error message: distribution.errors.full_messages,
                   status: 400, errorcode: 'invalid_distribution'
    end
  end

  # DELETE /distributions/1234
  def destroy
    distribution = Distribution.find(params[:id])
    # We don't allow deleting remote distributions
    distribution.readonly! if distribution.remote
    distribution.destroy

    render_ok
  end

  # GET /distributions/include_remotes
  def include_remotes
    @distributions = Distribution.all

    respond_to do |format|
      format.xml { render :index }
      format.json { render json: @distributions }
    end
  end

  # PUT /distributions/bulk_replace
  # and compatibility route: PUT /distributions/
  def bulk_replace
    errors = []
    distributions = []

    @body_xml.elements('distribution') do |distribution_xmlhash|
      distribution = Distribution.new_from_xmlhash(distribution_xmlhash)
      distributions << distribution
      errors << distributions.errors unless distribution.valid?
    end

    if errors.any?
      render_error message: errors.map(&:full_messages),
                   status: 400, errorcode: 'invalid_distributions'
    elsif distributions.empty?
      render_error message: 'No distributions found in body',
                   status: 400, errorcode: 'invalid_distributions'
    else
      Distribution.local.destroy_all
      distributions.map(&:save!)
      render_ok
    end
  end

  private

  def set_body_xml
    @body_xml = Xmlhash.parse(request.body.read)
  end
end
