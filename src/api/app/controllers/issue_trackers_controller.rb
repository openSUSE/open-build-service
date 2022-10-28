class IssueTrackersController < ApplicationController
  before_action :require_admin, only: [:create, :update, :destroy]

  validate_action index: { method: :get, response: :issue_trackers }
  validate_action show: { method: :get, response: :issue_tracker }
  validate_action create: { method: :post, request: :issue_tracker, response: :status }
  validate_action update: { method: :put, request: :issue_tracker }

  # GET /issue_trackers
  def index
    @issue_trackers = IssueTracker.all

    respond_to do |format|
      format.xml  { render xml: @issue_trackers.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS) }
    end
  end

  # GET /issue_trackers/<name>
  def show
    @issue_tracker = IssueTracker.find_by_name(params[:name])
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find issue tracker '#{params[:name]}'") && return unless @issue_tracker

    respond_to do |format|
      format.xml  { render xml: @issue_tracker.to_xml(IssueTracker::DEFAULT_RENDER_PARAMS) }
    end
  end

  # POST /issue_trackers
  def create
    xml = Nokogiri::XML(request.raw_post, &:strict).root
    @issue_tracker = IssueTracker.new(name: xml.xpath('name[1]/text()').to_s,
                                      kind: xml.xpath('kind[1]/text()').to_s,
                                      description: xml.xpath('description[1]/text()').to_s,
                                      regex: xml.xpath('regex[1]/text()').to_s,
                                      label: xml.xpath('label[1]/text()').to_s,
                                      url: xml.xpath('url[1]/text()').to_s,
                                      enable_fetch: xml.xpath('enable-fetch[1]/text()').to_s,
                                      issues_updated: Time.now,
                                      show_url: xml.xpath('show-url[1]/text()').to_s)
    respond_to do |format|
      if @issue_tracker.save
        format.xml  { render_ok }
      else
        format.xml  { render xml: @issue_tracker.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /issue_trackers/<name>
  def update
    respond_to do |format|
      xml = Nokogiri::XML(request.raw_post, &:strict).root
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

      issue_tracker = IssueTracker.find_by_name(params[:name])
      if issue_tracker
        issue_tracker.update(attribs)
      else
        IssueTracker.create(attribs)
      end
      format.xml { render_ok }
    end
  end

  # DELETE /issue_trackers/<name>
  def destroy
    @issue_tracker = IssueTracker.find_by_name(params[:name])
    render_error(status: 404, errorcode: 'not_found', message: "Unable to find issue tracker '#{params[:name]}'") && return unless @issue_tracker

    @issue_tracker.destroy

    render_ok
  end
end
