class IssueTrackersController < ApplicationController
  skip_before_filter :extract_user, :only => [:index, :show]
  before_filter :require_admin, :only => [:create, :update, :destroy]

  validate_action :index => {:method => :get, :response => :issue_trackers}
  validate_action :show => {:method => :get, :response => :issue_tracker}
  validate_action :create => {:method => :post, :request => :issue_tracker, :response => :issue_tracker}
  validate_action :update => {:method => :put, :request => :issue_tracker}

  $render_params = { :except => :id, :skip_types => true }

  # GET /issue_trackers
  # GET /issue_trackers.json
  # GET /issue_trackers.xml
  def index
    @issue_trackers = IssueTracker.all()

    respond_to do |format|
      format.xml  { render :xml => @issue_trackers.to_xml($render_params) }
      format.json { render :json => @issue_trackers.to_json($render_params) }
    end
  end

  # GET /issue_trackers/bnc
  # GET /issue_trackers/bnc.json
  # GET /issue_trackers/bnc.xml
  def show
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error :status => 404, :errorcode => "not_found", :message => "Unable to find issue tracker '#{params[:id]}'" and return
    end

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
      @issue_tracker = IssueTracker.new(params)
    rescue
      # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
      xml = Nokogiri::XML(request.raw_post).root
      @issue_tracker = IssueTracker.create(:name => xml.xpath('name[1]/text()').to_s,
                                           :kind => xml.xpath('kind[1]/text()').to_s,
                                           :description => xml.xpath('description[1]/text()').to_s,
                                           :regex => xml.xpath('regex[1]/text()').to_s,
                                           :url => xml.xpath('url[1]/text()').to_s,
                                           :show_url => xml.xpath('show-url[1]/text()').to_s)
    end

  respond_to do |format|
      if @issue_tracker
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
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error :status => 404, :errorcode => "not_found", :message => "Unable to find issue tracker '#{params[:id]}'" and return
    end

    respond_to do |format|
      begin
        ret = @issue_tracker.update_attributes(request.request_parameters)
      rescue ActiveRecord::UnknownAttributeError
        # User didn't really upload www-form-urlencoded data but raw XML, try to parse that
        xml = Nokogiri::XML(request.raw_post).root
        attribs = {}
        attribs[:name] = xml.xpath('name[1]/text()').to_s unless xml.xpath('name[1]/text()').empty?
        attribs[:kind] = xml.xpath('kind[1]/text()').to_s unless xml.xpath('kind[1]/text()').empty?
        attribs[:description] = xml.xpath('description[1]/text()').to_s unless xml.xpath('description[1]/text()').empty?
        attribs[:regex] = xml.xpath('regex[1]/text()').to_s unless xml.xpath('regex[1]/text()').empty?
        attribs[:url] = xml.xpath('url[1]/text()').to_s unless xml.xpath('url[1]/text()').empty?
        attribs[:show_url] = xml.xpath('show-url[1]/text()').to_s unless xml.xpath('show-url[1]/text()').empty?
        ret = @issue_tracker.update_attributes(attribs)
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
    @issue_tracker = IssueTracker.find_by_name(params[:id])
    unless @issue_tracker
      render_error :status => 404, :errorcode => "not_found", :message => "Unable to find issue tracker '#{params[:id]}'" and return
    end
    @issue_tracker.destroy

    respond_to do |format|
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  # GET /issue_trackers/show_url_for?issue=bnc%231234
  # GET /issue_trackers/show_url_for?issue=CVS-2011-1234
  def show_url_for
    unless params[:issue]
      render_error :status => 400, :errorcode => "missing_parameter", :message => "Please provide an issue parameter" and return
    end
    IssueTracker.all.each do |it|
      if it.matches?(params[:issue])
        render :text => it.show_url_for(params[:issue]) and return
      end
    end
    head 404
  end

  # GET /issue_trackers/issues_in?text=...
  def issues_in
    unless params[:text]
      render_error :status => 400, :errorcode => "missing_parameter", :message => "Please provide a text parameter" and return
    end
    ret = {} # Abuse Hash as mathematical set
    IssueTracker.regexen.each do |regex|
      # Ruby's string#scan method unfortunately doesn't return the whole match if a RegExp contains groups.
      # RegExp#match does that but it doesn't advance the string if called consecutively. Thus we have to do
      # this it hand...
      text = params[:text]
      begin
        match = regex.match(text)
        if match
          ret[match[0]] = nil
          text = text[match.end(0)+1..-1]
        end
      end while match
    end
    render :json => ret.keys
  end

end
