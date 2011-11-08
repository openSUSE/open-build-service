class IssueTrackersController < ApplicationController
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :destroy]

  validate_action :index => {:method => :get, :response => :issue_trackers}
  validate_action :show => {:method => :get, :response => :issue_tracker}
  validate_action :create => {:method => :post, :request => :issue_tracker, :response => :issue_tracker}
  validate_action :update => {:method => :put, :request => :issue_tracker}
  validate_action :destroy => {:method => :delete, :request => :issue_tracker}

  $render_params = { :include => { :acronyms => { :except => [:id, :issue_tracker_id] }}, :except => :id, :skip_types => true }

  # GET /issue_trackers
  # GET /issue_trackers.json
  # GET /issue_trackers.xml
  def index
    @issue_trackers = IssueTracker.all(:include => :acronyms)

    respond_to do |format|
      format.xml  { render :xml => @issue_trackers.to_xml($render_params) }
      format.json { render :json => @issue_trackers.to_json($render_params) }

    end
  end

  # GET /issue_trackers/bnc
  # GET /issue_trackers/bnc.json
  # GET /issue_trackers/bnc.xml
  def show
    unless params[:id]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    issue_tracker_acronym = IssueTrackerAcronym.find_by_name(params[:id])
    unless issue_tracker_acronym
      render_error :status => 400, :errorcode => "unknown_issue_tracker", :message => "Issue tracker does not exist: #{params[:id]}" and return
    end
    @issue_tracker = IssueTracker.find(issue_tracker_acronym.issue_tracker_id)

    respond_to do |format|
      format.xml  { render :xml => @issue_tracker.to_xml($render_params) }
      format.json { render :json => @issue_tracker.to_json($render_params) }
    end
  end

  # POST /issue_trackers
  # POST /issue_trackers.json
  # POST /issue_trackers.xml
  def create
    begin
      @issue_tracker = IssueTracker.new(params) # TODO: subject to fail!
    rescue
      xml = Nokogiri::XML(request.raw_post).root
      @issue_tracker = IssueTracker.create(:name => xml.xpath('name[1]/text()').to_s,
                                           :url => xml.xpath('url[1]/text()').to_s,
                                           :show_url => xml.xpath('show-url[1]/text()').to_s)
      success = false
      if @issue_tracker
        success = true
        xml.xpath('acronyms/acronym').each do |acronym|
          success &&= !@issue_tracker.acronyms.create(:name => acronym.xpath('name[1]/text()').to_s).nil?
        end
      end
    end

    respond_to do |format|
      if success
        format.xml  { render :xml => @issue_tracker.to_xml($render_params), :status => :created, :location => @issue_tracker }
        format.json { render :json => @issue_tracker.to_json($render_params), :status => :created, :location => @issue_tracker }
      else
        format.xml  { render :xml => @issue_tracker.errors, :status => :unprocessable_entity }
        format.json { render :json => @issue_tracker.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /issue_trackers/bnc
  # PUT /issue_trackers/bnc.json
  # PUT /issue_trackers/bnc.xml
  def update
    unless params[:id]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    issue_tracker_acronym = IssueTrackerAcronym.find_by_name(params[:id])
    unless issue_tracker_acronym
      render_error :status => 400, :errorcode => "unknown_issue_tracker", :message => "Issue tracker does not exist: #{params[:id]}" and return
    end
    @issue_tracker = IssueTracker.find(issue_tracker_acronym.issue_tracker_id)

    respond_to do |format|
      begin
        ret = @issue_tracker.update_attributes(request.request_parameters)
      rescue ActiveRecord::UnknownAttributeError
        # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
        xml = Nokogiri::XML(request.raw_post).root
        attribs = {}
        attribs[:name] = xml.xpath('name[1]/text()').to_s unless xml.xpath('name[1]/text()').empty?
        attribs[:url] = xml.xpath('url[1]/text()').to_s unless xml.xpath('url[1]/text()').empty?
        attribs[:show_url] = xml.xpath('show-url[1]/text()').to_s unless xml.xpath('show-url[1]/text()').empty?
        ret = @issue_tracker.update_attributes(attribs)
        unless xml.xpath('acronyms/acronym').empty?
          # Found acronyms in XML, drop all old and re-create. Technically we could update acronyms based on the ids in the XML...
          IssueTrackerAcronym.delete_all(:issue_tracker_id => @issue_tracker.id)
          xml.xpath('acronyms/acronym').each do |acronym|
            IssueTrackerAcronym.create!(:issue_tracker_id => @issue_tracker.id, :name => acronym.xpath('name[1]/text()').to_s)
          end
        end
      end
      if ret
        format.xml  { head :ok }
        format.json { head :ok }
      else
        format.xml  { render :xml => @issue_tracker.errors, :status => :unprocessable_entity }
        format.json { render :json => @issue_tracker.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /issue_trackers/bnc
  # DELETE /issue_trackers/bnc.xml
  # DELETE /issue_trackers/bnc.json
  def destroy
    unless params[:id]
      render_error :status => 400, :errorcode => "missing_parameter'", :message => "Missing parameter 'name'" and return
    end
    issue_tracker_acronym = IssueTrackerAcronym.find_by_name(params[:id])
    unless issue_tracker_acronym
      render_error :status => 400, :errorcode => "unknown_issue_tracker", :message => "Issue tracker does not exist: #{params[:id]}" and return
    end
    @issue_tracker = IssueTracker.find(issue_tracker_acronym.issue_tracker_id)
    @issue_tracker.destroy

    respond_to do |format|
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end
end
