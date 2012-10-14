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
      subprojects = Project.where("projects.name like ?",  pro.name + ":").
        where(type_id: mi.id).joins(:repositories => :release_targets).
        where("release_targets.trigger = 'maintenance'")
      infos[:incidents] = subprojects.select("projects.name").all

      maintained_projects = []
      pro.maintained_projects.each do |mp|
        maintained_projects << mp.name
      end
      infos[:maintained_projects] = maintained_projects

    end

    infos[:linking_projects] = pro.find_linking_projects.map { |p| p.name }

    infos[:requests] = reviews_priv(params[:project])

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
  
    render :json => infos
  end

  def reviews_priv(prj)
    prj = Project.find_by_name! prj
    
    rel = BsRequest.collection(project: params[:project], states: ['review'], roles: ['reviewer'])
    reviews = rel.select("bs_request.id").all.map { |r| r.id }

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['target'])
    targets = rel.select("bs_request.id").all.map { |r| r.id }

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_incident'])
    incidents = rel.select("bs_request.id").all.map { |r| r.id }
    
    if prj.project_type == "maintenance"
      rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_release'], subprojects: true)
      maintenance_release = rel.select("bs_request.id").all.map { |r| r.id }
    else
      maintenance_release = []
    end

    { 'reviews' => reviews, 'targets' => targets, 'incidents' => incidents, 'maintenance_release' => maintenance_release }
  end

  def project_requests
    required_parameters :project
    
    render json: reviews_priv(params[:project])
  end
end
