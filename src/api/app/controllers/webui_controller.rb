require 'json/ext'

require_dependency 'status_helper'
include SearchHelper

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
      subprojects = Project.where("projects.name like ?", pro.name + ":%").
          where(type_id: mi.id).joins(:repositories => :release_targets).
          where("release_targets.trigger = 'maintenance'")
      infos[:incidents] = subprojects.pluck("projects.name").sort.uniq

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
      rel = BsRequest.collection(project: params[:project], states: ['new', 'review'], types: ['maintenance_release'], roles: ['source'])
      infos[:open_release_requests] = rel.pluck("bs_requests.id")
    end

    render json: infos
  end

  def reviews_priv(prj)
    prj = Project.find_by_name! prj

    rel = BsRequest.collection(project: params[:project], states: ['review'], roles: ['reviewer'])
    reviews = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['target'])
    targets = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_incident'])
    incidents = rel.pluck("bs_requests.id")

    if prj.project_type == "maintenance"
      rel = BsRequest.collection(project: params[:project], states: ['new'], roles: ['source'], types: ['maintenance_release'], subprojects: true)
      maintenance_release = rel.pluck("bs_requests.id")
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
    required_parameters :login
    login = params[:login]
    result = {}

    rel = BsRequest.collection(user: login, states: ['declined'], roles: ['creator'])
    result[:declined] = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(user: login, states: ['new'], roles: ['maintainer'])
    result[:new] = rel.pluck("bs_requests.id")

    rel = BsRequest.collection(user: login, roles: ['reviewer'], reviewstates: ['new'], states: ['review'])
    result[:reviews] = rel.pluck("bs_requests.id")

    render json: result
  end

  def person_involved_requests
    required_parameters :login
    rel = BsRequest.collection(user: params[:login], states: ['new', 'review'])
    result = rel.pluck("bs_requests.id")

    render json: result
  end

  # TODO - put in use
  def package_flags
    required_parameters :project, :package

    project_name = params[:project]
    package_name = params[:package]

    valid_package_name! package_name

    pack = Package.get_by_project_and_name(project_name, package_name, use_source: false)
    render json: pack.expand_flags
  end

  # TODO - put in use
  def project_flags
    required_parameters :project

    project_name = params[:project]

    prj = Project.get_by_name(project_name)
    render json: prj.expand_flags
  end

  def request_show
    required_parameters :id

    req = BsRequest.find(params[:id])
    render json: req.webui_infos
  end

  def request_ids
    required_parameters :ids

    rel = BsRequest.where(id: params[:ids].split(','))
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
    if params[:project].blank? && params[:user].blank? && params[:package].blank?
      render_error :status => 400, :errorcode => 'require_filter',
                   :message => "This call requires at least one filter, either by user, project or package"
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
        rel = BsRequest.collection(params.merge({ roles: ['reviewer'] }))
        ids = rel.pluck("bs_requests.id")
        rel = BsRequest.collection(params.merge({ roles: ['target', 'source'] }))
      end
    end
    rel = BsRequest.collection(params) unless rel
    ids.concat(rel.pluck("bs_requests.id"))

    render json: ids.uniq.sort
  end

  def change_role
    required_parameters :project

    if params[:package].blank?
      target = Project.find_by_name!(params[:project])
    else
      target = Package.find_by_project_and_name(params[:project], params[:package])
    end

    if params.has_key? :userid
      object = User.get_by_login(params[:userid])
    elsif params.has_key? :groupid
      object = Group.get_by_title(params[:groupid])
    else
      raise MissingParameterError, "Neither userid nor groupid given"
    end

    begin
      if params[:todo].to_s == 'remove'
        role = nil
        role = Role.find_by_title(params[:role]) if params[:role]
        target.remove_role(object, role)
      elsif params[:todo].to_s == 'add'
        role = Role.find_by_title!(params[:role])
        target.add_role(object, role)
      else
        raise MissingParameterError, "Paramter todo is not 'add' or 'remove'"
      end
    rescue ActiveRecord::RecordInvalid => e
      render_error status: 400, errorcode: 'change_role_failed', message: e.record.errors.full_messages.join('\n')
      return
    end
    render json: 'ok'
  end

  def all_projects
    # return all projects and their title
    ret = {}
    atype = AttribType.find_by_namespace_and_name('OBS', 'VeryImportantProject')
    important = {}
    Project.find_by_attribute_type(atype).pluck("projects.id").each do |p|
      important[p] = 1
    end
    deleted =Project.find_by_name("deleted")
    projects = Project.where("id != ?", deleted.id).pluck(:id, :name, :title)
    projects.each do |id, name, title|
      ret[name] = { title: title, important: important[id] ? true : false }
    end
    render text: JSON.fast_generate(ret), content_type: "application/json"
  end

  def owner
    required_parameters :binary

    Suse::Backend.start_test_backend if Rails.env.test?

    @owners = search_owner(params, params[:binary])
  end

  def project_status_attributes(packages, namespace, name)
    ret = Hash.new
    at = AttribType.find_by_namespace_and_name(namespace, name)
    return unless at
    attribs = at.attribs.where(db_package_id: packages)
    AttribValue.where(attrib_id: attribs).joins(:attrib).pluck("attribs.db_package_id, value").each do |id, value|
      yield id, value
    end
    ret
  end

  def project_status
    required_parameters :project
    project = Project.where(name: params[:project]).includes(:packages).first
    status = Hash.new

    # needed to map requests to package id
    name2id = Hash.new

    prj_status = ProjectStatusHelper.calc_status(project, pure_project: true)

    no_project = "_none_"
    all_projects = "_all_"
    current_develproject = params[:filter_devel] || all_projects
    @ignore_pending = params[:ignore_pending] == "true"
    @limit_to_fails = params[:limit_to_fails] == "true" 
    @limit_to_old = params[:limit_to_old] == "true"
    @include_versions = params[:include_versions] == "true"
    filter_for_user = User.get_by_login(params[:filter_for_user]) unless params[:filter_for_user].blank?

    @develprojects = Hash.new
    packages_to_filter_for = nil
    if filter_for_user 
      packages_to_filter_for = filter_for_user.user_relevant_packages_for_status
    end
    prj_status.each_value do |value|
      if value.develpack
        dproject = value.devel_project
        @develprojects[dproject] = 1
        if (current_develproject != dproject or current_develproject == no_project) and current_develproject != all_projects
          next
        end
      else
        next if @current_develproject == no_project
      end
      if filter_for_user
        if value.develpack
          next unless packages_to_filter_for.include? value.develpack.db_package_id
        else
          next unless packages_to_filter_for.include? value.db_package_id
        end
      end
      status[value.db_package_id] = value
      name2id[value.name] = value.db_package_id
    end

    project_status_attributes(status.keys, 'OBS', 'ProjectStatusPackageFailComment') do |package, value|
      status[package].failed_comment = value
    end

    if @include_versions || @limit_to_old

      project_status_attributes(status.keys, 'openSUSE', 'UpstreamVersion') do |package, value|
        status[package].upstream_version = value
      end
      project_status_attributes(status.keys, 'openSUSE', 'UpstreamTarballURL') do |package, value|
        status[package].upstream_url= value
      end
    end

    # we do not filter requests for project because we need devel projects too later on and as long as the
    # number of open requests is limited this is the easiest solution
    raw_requests = BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
        where(bs_request_actions: { type: 'submit' }).includes(:bs_request_actions)

    submits = Hash.new
    raw_requests.each do |r|
      r.bs_request_actions.each do |action|
        if r.state == :declined
          next if action.target_project != project.name || !name2id.has_key?(action.target_package)
          status[name2id[action.target_package]].declined_request = action
        else
          key = "#{action.target_project}/#{action.target_package}"
          submits[key] ||= Array.new
          submits[key] << r
        end
      end
    end

    @packages = Array.new
    status.each_value do |p|
      currentpack = Hash.new
      pname = p.name
      #next unless pname =~ %r{mkv.*}
      currentpack['name'] = pname
      currentpack['failedcomment'] = p.failed_comment

      newest = 0
      p.buildinfo.fails.each do |repo, tuple|
        next if repo =~ /snapshot/
        ftime = Integer(tuple[0]) rescue 0
        next if newest > ftime
        next if tuple[1] != p.srcmd5
        currentpack['failedarch'] = repo.split('/')[1]
        currentpack['failedrepo'] = repo.split('/')[0]
        newest = ftime
        currentpack['firstfail'] = newest
      end if p.buildinfo

      currentpack['problems'] = Array.new
      currentpack['requests_from'] = Array.new
      currentpack['requests_to'] = Array.new

      key = project.name + "/" + pname
      if submits.has_key? key
        currentpack['requests_from'].concat(submits[key].map {|r| r.id })
      end

      if p.develpack
        dproject = p.devel_project
        currentpack['develproject'] = dproject
        currentpack['develpackage'] = p.devel_package
        key = "%s/%s" % [dproject, p.devel_package]
        if submits.has_key? key
          currentpack['requests_to'].concat(submits[key].map {|r| r.id })
        end
        next if !currentpack['requests_from'].empty? && @ignore_pending
        dp = p.develpack
        if dp
          currentpack['develmd5'] = dp.verifymd5
          currentpack['develmd5'] ||= dp.srcmd5
          currentpack['develchangesmd5'] = dp.changesmd5
          currentpack['develmtime'] = dp.maxmtime

          if dp.error
            currentpack['problems'] << 'error-' + dp.error
          end

          newest = 0
          p.buildinfo.fails.each do |repo, tuple|
            ftime = Integer(tuple[0]) rescue 0
            next if newest > ftime
            next if tuple[1] != dp.srcmd5
            frepo = repo
            currentpack['develfailedarch'] = frepo.split('/')[1]
            currentpack['develfailedrepo'] = frepo.split('/')[0]
            newest = ftime
            currentpack['develfirstfail'] = newest
          end if p.buildinfo

        end

        if p.buildinfo
          currentpack['version'] = p.buildinfo.version
          if p.upstream_version
            begin
              gup = Gem::Version.new(p.buildinfo.version)
              guv = Gem::Version.new(p.upstream_version)
            rescue ArgumentError
              # if one of the versions can't be parsed we simply can't say
            end

            if gup && guv && gup < guv
              currentpack['upstream_version'] = p.upstream_version
              currentpack['upstream_url'] = p.upstream_url
            end
          end
        end

        currentpack['md5'] = p.verifymd5
        currentpack['md5'] ||= p.srcmd5

        currentpack['changesmd5'] = p.changesmd5

        if currentpack['md5'] && currentpack['develmd5'] && currentpack['md5'] != currentpack['develmd5']
          if p.declined_request &&
              p.declined_request.source_project == dp.project &&
              p.declined_request.source_package == dp.name


            sourcerev = Rails.cache.fetch("rev-#{dp.project}-#{dp.name}-#{currentpack['md5']}") do
              Directory.hashed(project: dp.project, package: dp.name)['rev']
            end
            if sourcerev == p.declined_request.source_rev
              currentpack['currently_declined'] = p.declined_request.bs_request_id
              currentpack['problems'] << 'currently_declined'
            end
          end
          if currentpack['currently_declined'].nil?
            if currentpack['changesmd5'] != currentpack['develchangesmd5']
              currentpack['problems'] << 'different_changes'
            else
              currentpack['problems'] << 'different_sources'
            end
          end
        end
      end

      unless p.link.project.blank?
        if currentpack['md5'] != p.link.targetmd5
          currentpack['problems'] << 'diff_against_link'
          currentpack['lproject'] = p.link.project
          currentpack['lpackage'] = p.link.package
        end
      end

      if @limit_to_fails
        next if !currentpack['firstfail']
      else
        next unless (currentpack['firstfail'] or currentpack['failedcomment'] or currentpack['upstream_version'] or
            !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
        if @limit_to_old
          next if (currentpack['firstfail'] or currentpack['failedcomment'] or
              !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
        end
      end
      #currentpack['thefullthing'] = p
      @packages << currentpack
    end

    render json: {packages: @packages, projects: @develprojects.keys}
  end
end
