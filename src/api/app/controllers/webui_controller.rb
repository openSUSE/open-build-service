class WebuiController < ApplicationController

  # return all data related that the webui wants to show on /project/show
  def project_infos
    required_parameters :project
    infos = Hash.new
    pro = Project.find_by_name!(params[:project])
    infos[:name] = pro.name
    infos[:packages] = Array.new
    pro.expand_all_packages.each do |p|
      if p.db_project_id==pro.id
        infos[:packages] << [p.name, nil]
      else
        infos[:packages] << [p.name, p.project.name]
      end
    end

    infos[:xml] = pro.to_axml

    pm = pro.maintenance_project
    infos[:maintenance_project] = pm.name if pm

    if pro.project_type == "maintenance"
      mi = DbProjectType.find_by_name!('maintenance_incident')
      subprojects = Project.where("projects.name like ?",  pro.name + ":%").
        where(type_id: mi.id).joins(:repositories => :release_targets).
        where("release_targets.trigger = 'maintenance'")
      infos[:incidents] = subprojects.select("projects.name").map {|p| p.name }.sort.uniq

      maintained_projects = []
      pro.maintained_projects.each do |mp|
        maintained_projects << mp.name
      end
      infos[:maintained_projects] = maintained_projects

    end

    infos[:linking_projects] = pro.find_linking_projects.map { |p| p.name }

    reqs = reviews_priv(params[:project])
    infos[:requests] = (reqs['reviews'] + reqs['targets'] + reqs['incidents'] + reqs['maintenance_release']).sort.uniq

    infos[:nr_of_problem_packages] = 0
    
    begin
      result = backend_get("/build/#{URI.escape(pro.name)}/_result?view=status&code=failed&code=broken&code=unresolvable")
    rescue ActiveXML::Transport::NotFoundError
      result = nil
    end
    if result
      ret = {}
      Xmlhash.parse(result).elements('result') do |r|
        r.elements('status') { |p| ret[p['package']] = 1 }
      end
      infos[:nr_of_problem_packages] = ret.keys.size
    end

    if pro.project_type == 'maintenance_incident'
      rel = BsRequest.collection(project: params[:project], states: ['new','review'], types: ['maintenance_release'], roles: ['source'])
      infos[:open_release_requests] = rel.select("bs_request.id").all.map { |r| r.id }
    end
  
    render json: infos
  end

  def reviews_priv(prj)
    prj = Project.find_by_name! prj
    
    rel = BsRequest.collection(project: params[:project], states: ['review'], roles: ['reviewer'])
    reviews = rel.select("bs_requests.id").all.map { |r| r.id }

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['target'])
    targets = rel.select("bs_requests.id").all.map { |r| r.id }

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_incident'])
    incidents = rel.select("bs_requests.id").all.map { |r| r.id }
    
    if prj.project_type == "maintenance"
      rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_release'], subprojects: true)
      maintenance_release = rel.select("bs_requests.id").all.map { |r| r.id }
    else
      maintenance_release = []
    end

    { 'reviews' => reviews, 'targets' => targets, 'incidents' => incidents, 'maintenance_release' => maintenance_release }
  end

  def project_requests
    required_parameters :project
    
    render json: reviews_priv(params[:project])
  end

  def person_requests_that_need_work
    valid_http_methods :get
    required_parameters :login
    login = params[:login]
    result = {}

    rel = BsRequest.collection(user: login, states: ['declined'], roles: ['creator'])
    result[:declined] = rel.select("bs_requests.id").all.map { |r| r.id }

    rel = BsRequest.collection(user: login, states: ['new'], roles: ['maintainer'])
    result[:new] = rel.select("bs_requests.id").all.map { |r| r.id }

    rel = BsRequest.collection(user: login, roles: ['reviewer'], reviewstates: ['new'], states: ['review'])
    result[:reviews] = rel.select("bs_requests.id").all.map { |r| r.id }

    render json: result
  end

  def person_involved_requests
    valid_http_methods :get
    required_parameters :login
    rel = BsRequest.collection(user: params[:login], states: ['new', 'review'])
    result = rel.select("bs_requests.id").all.map { |r| r.id }

    render json: result
  end

  # TODO - put in use
  def package_flags
    valid_http_methods :get
    required_parameters :project, :package

    project_name = params[:project]
    package_name = params[:package]

    unless valid_package_name? package_name
      render_error :status => 400, :errorcode => "invalid_package_name",
        :message => "invalid package name '#{package_name}'"
      return
    end

    pack = Package.get_by_project_and_name( project_name, package_name, use_source: false )
    render json: pack.expand_flags
  end

  # TODO - put in use
  def project_flags
    valid_http_methods :get
    required_parameters :project

    project_name = params[:project]

    prj = Project.get_by_name( project_name )
    render json: prj.expand_flags
  end

  def request_show
    valid_http_methods :get
    required_parameters :id

    req = BsRequest.find(params[:id])
    render json: req.webui_infos
  end

  def request_ids
    valid_http_methods :get
    required_parameters :ids
    
    rel = BsRequest.where( id: params[:ids].split(',') )
    rel = rel.includes({ bs_request_actions: :bs_request_action_accept_info }, :bs_request_histories)
    rel = rel.order('bs_requests.id')

    result = []
    rel.each do |r|
      result << r.webui_infos(diffs: false)
    end
    render json: result
  end

  def request_list
    # Do not allow a full collection to avoid server load
    if params[:project].blank?
      render_error :status => 400, :errorcode => 'require_filter',
      :message => "This call requires at least one filter, either by user, project or package or states or types or reviewstates"
      return
    end
    
    # convert comma seperated values into arrays
    if params[:roles]
      roles = params[:roles].split(',') 
    else
      roles = []
    end
    types = params[:types].split(',') if params[:types]
    if params[:states]
      states = params[:states].split(',') 
    else
      states = []
    end
    review_states = params[:reviewstates].split(',') if params[:reviewstates]
    
    params.merge!({ states: states, types: types, review_states: review_states, roles: roles })
    logger.debug "PARAMS #{params.inspect}"
    ids = []
    rel = nil

    if params[:project]
      if roles.empty? && (states.empty? || states.include?('review')) # it's wiser to split the queries
        rel = BsRequest.collection( params.merge({ roles: ['reviewer'] } ) )
        rel.select("bs_requests.id")
        rel.each { |r| ids << r.id }
        rel = BsRequest.collection( params.merge({ roles: ['target', 'source'] } ) )
      end
    end
    rel = BsRequest.collection( params ) unless rel
    rel.select("bs_requests.id")
    rel.each { |r| ids << r.id }
    
    render json: ids.uniq.sort
  end

end
