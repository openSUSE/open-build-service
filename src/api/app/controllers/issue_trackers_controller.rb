class IssueTrackersController < ApplicationController
  before_action :require_admin, only: [:create, :update, :destroy]

  validate_action index: { method: :get, response: :issue_trackers }
  validate_action show: { method: :get, response: :issue_tracker }
  validate_action create: { method: :post, request: :issue_tracker, response: :issue_tracker }
  validate_action update: { method: :put, request: :issue_tracker }

  # GET /issue_trackers
  # GET /issue_trackers.json
  # GET /issue_trackers.xml
  def index
    @issue_trackers = IssueTracker.all

    respond_to do |format|
      format.xml  { render xml: @issue_trackers.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS) }
      format.json { render json: @issue_trackers.to_json(IssueTracker::DEFAULT_RENDER_PARAMS) }
    end
  end

  # GET /issue_trackers/bnc
  # GET /issue_trackers/bnc.json
  # GET /issue_trackers/bnc.xml
  def show
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error(status: 404, errorcode: "not_found", message: "Unable to find issue tracker '#{params[:id]}'") && return
    end

    respond_to do |format|
      format.xml  { render xml: @issue_tracker.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS) }
      format.json { render json: @issue_tracker.to_json(IssueTracker::DEFAULT_RENDER_PARAMS) }
    end
  end

  # POST /issue_trackers
  # POST /issue_trackers.json
  # POST /issue_trackers.xml
  def create
    begin
      @issue_tracker = IssueTracker.new(params)
    rescue
      # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
      xml = Nokogiri::XML(request.raw_post).root
      @issue_tracker = IssueTracker.create(name: xml.xpath('name[1]/text()').to_s,
                                           kind: xml.xpath('kind[1]/text()').to_s,
                                           description: xml.xpath('description[1]/text()').to_s,
                                           regex: xml.xpath('regex[1]/text()').to_s,
                                           label: xml.xpath('label[1]/text()').to_s,
                                           url: xml.xpath('url[1]/text()').to_s,
                                           enable_fetch: xml.xpath('enable-fetch[1]/text()').to_s,
                                           issues_updated: Time.now,
                                           show_url: xml.xpath('show-url[1]/text()').to_s)
    end

    respond_to do |format|
      if @issue_tracker
        format.xml  { render xml: @issue_tracker.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS), status: :created, location: @issue_tracker }
        format.json { render json: @issue_tracker.to_json(IssueTracker::DEFAULT_RENDER_PARAMS), status: :created, location: @issue_tracker }
      else
        format.xml  { render xml: @issue_tracker.errors, status: :unprocessable_entity }
        format.json { render json: @issue_tracker.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /issue_trackers/bnc
  # PUT /issue_trackers/bnc.json
  # PUT /issue_trackers/bnc.xml
  def update
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error(status: 404, errorcode: "not_found", message: "Unable to find issue tracker '#{params[:id]}'") && return
    end

    respond_to do |format|
      begin
        ret = @issue_tracker.update_attributes(request.request_parameters)
      rescue ActiveRecord::UnknownAttributeError, ActiveModel::MassAssignmentSecurity::Error
        # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
        xml = Nokogiri::XML(request.raw_post).root
        attribs = {}
        attribs[:name] = xml.xpath('name[1]/text()').to_s unless xml.xpath('name[1]/text()').empty?
        attribs[:kind] = xml.xpath('kind[1]/text()').to_s unless xml.xpath('kind[1]/text()').empty?
        attribs[:description] = xml.xpath('description[1]/text()').to_s unless xml.xpath('description[1]/text()').empty?
        attribs[:user] = xml.xpath('user[1]/text()').to_s unless xml.xpath('user[1]/text()').empty?
        attribs[:password] = xml.xpath('password[1]/text()').to_s unless xml.xpath('password[1]/text()').empty?
        attribs[:regex] = xml.xpath('regex[1]/text()').to_s unless xml.xpath('regex[1]/text()').empty?
        attribs[:url] = xml.xpath('url[1]/text()').to_s unless xml.xpath('url[1]/text()').empty?
        attribs[:label] = xml.xpath('label[1]/text()').to_s unless xml.xpath('label[1]/text()').empty?
        attribs[:enable_fetch] = xml.xpath('enable-fetch[1]/text()').to_s unless xml.xpath('enable-fetch[1]/text()').empty?
        attribs[:show_url] = xml.xpath('show-url[1]/text()').to_s unless xml.xpath('show-url[1]/text()').empty?
        ret = @issue_tracker.update_attributes(attribs)
      end
      if ret
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.xml  { render xml: @issue_tracker.errors, status: :unprocessable_entity }
        format.json { render json: @issue_tracker.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /issue_trackers/bnc
  # DELETE /issue_trackers/bnc.xml
  # DELETE /issue_trackers/bnc.json
  def destroy
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error(status: 404, errorcode: "not_found", message: "Unable to find issue tracker '#{params[:id]}'") && return
    end
    @issue_tracker.destroy

    respond_to do |format|
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end
end
