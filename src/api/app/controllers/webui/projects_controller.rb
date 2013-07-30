require_dependency 'status_helper'

class Webui::ProjectsController < Webui::BaseController

  def index
    # return all projects and their title
    ret = {}
    atype = AttribType.find_by_namespace_and_name('OBS', 'VeryImportantProject')
    important = {}
    Project.find_by_attribute_type(atype).pluck("projects.id").each do |p|
      important[p] = 1
    end
    projects = Project.where("name <> ?", "deleted").pluck(:id, :name, :title)
    projects.each do |id, name, title|
      ret[name] = { title: title, important: important[id] ? true : false }
    end
    render json: ret
  end

  # return all data related that the webui wants to show on /project/show
  def infos
    required_parameters :id
    project_name = params[:id]
    infos = Hash.new
    pro = Project.find_by_name!(project_name)
    infos[:name] = pro.name
    infos[:packages] = Array.new
    packages=pro.expand_all_packages
    prj_names = Hash.new
    Project.where(id: packages.map {|a| a[1]}.uniq).pluck(:id, :name).each do |id, name|
      prj_names[id] = name
    end
    packages.each do |name, prj_id|
      if prj_id==pro.id
        infos[:packages] << [name, nil]
      else
        infos[:packages] << [name, prj_names[prj_id]]
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

    reqs = pro.request_ids_by_class
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
      rel = BsRequest.collection(project: project_name, states: ['new', 'review'], types: ['maintenance_release'], roles: ['source'])
      infos[:open_release_requests] = rel.pluck("bs_requests.id")
    end

    render json: infos
  end

  def status
    required_parameters :id
    project = Project.where(name: params[:id]).includes(:packages).first
    status = Hash.new

    # needed to map requests to package id
    name2id = Hash.new

    prj_status = ProjectStatusHelper.calc_status(project, pure_project: true)

    logger.debug "prj_status"

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
    logger.debug "attributes"

    # we do not filter requests for project because we need devel projects too later on and as long as the
    # number of open requests is limited this is the easiest solution
    raw_requests = BsRequest.order(:id).where(state: [:new, :review, :declined]).joins(:bs_request_actions).
        where(bs_request_actions: { type: 'submit' }).pluck("bs_requests.id", "bs_requests.state",
                                                            "bs_request_actions.target_project",
                                                            "bs_request_actions.target_package" )

    submits = Hash.new
    raw_requests.each do |id, state, tproject, tpackage|
      if state == "declined"
        next if tproject != project.name || !name2id.has_key?(tpackage)
        status[name2id[tpackage]].declined_request = BsRequest.find(id)
      else
        key = "#{tproject}/#{tpackage}"
        submits[key] ||= Array.new
        submits[key] << id
      end
    end

    @packages = Array.new
    status.each_value do |p|
      currentpack = Hash.new
      pname = p.name

      currentpack['name'] = pname
      currentpack['failedcomment'] = p.failed_comment unless p.failed_comment.blank?

      newest = 0

      p.fails.each do |repo, arch, time, md5|
        next if newest > time
        next if md5 != p.srcmd5
        currentpack['failedarch'] = arch
        currentpack['failedrepo'] = repo
        newest = time
        currentpack['firstfail'] = newest
      end
      next if !currentpack['firstfail'] && @limit_to_fails

      currentpack['problems'] = Array.new
      currentpack['requests_from'] = Array.new
      currentpack['requests_to'] = Array.new

      key = project.name + "/" + pname
      if submits.has_key? key
        currentpack['requests_from'].concat(submits[key])
      end

      currentpack['md5'] = p.verifymd5
      currentpack['md5'] ||= p.srcmd5

      dp = p.develpack
      if dp
        dproject = p.devel_project
        currentpack['develproject'] = dproject
        currentpack['develpackage'] = p.devel_package
        key = "%s/%s" % [dproject, p.devel_package]
        if submits.has_key? key
          currentpack['requests_to'].concat(submits[key])
        end
        next if !currentpack['requests_from'].empty? && @ignore_pending
        
        currentpack['develmd5'] = dp.verifymd5
        currentpack['develmd5'] ||= dp.srcmd5
        
        if dp.error
          currentpack['problems'] << 'error-' + dp.error
        end

        if currentpack['md5'] && currentpack['develmd5'] && currentpack['md5'] != currentpack['develmd5']
          if p.declined_request
            p.declined_request.bs_request_actions.each do |action|
              next unless action.source_project == dp.project && action.source_package == dp.name

              sourcerev = Rails.cache.fetch("rev-#{dp.project}-#{dp.name}-#{currentpack['md5']}") do
                Directory.hashed(project: dp.project, package: dp.name)['rev']
              end
              if sourcerev == action.source_rev
                currentpack['currently_declined'] = p.declined_request.id
                currentpack['problems'] << 'currently_declined'
              end
            end
          end
          if currentpack['currently_declined'].nil?
            if p.changesmd5 != dp.changesmd5
              currentpack['problems'] << 'different_changes'
            else
              currentpack['problems'] << 'different_sources'
            end
          end
        end
      end
      currentpack.merge!(project_status_set_version(p))

      unless p.link.project.blank?
        if currentpack['md5'] != p.link.targetmd5
          currentpack['problems'] << "diff_against_link"
          currentpack['lproject'] = p.link.project
          currentpack['lpackage'] = p.link.package
        end
      end

      next unless (currentpack['firstfail'] or currentpack['failedcomment'] or currentpack['upstream_version'] or
          !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
      if @limit_to_old
        next if (currentpack['firstfail'] or currentpack['failedcomment'] or
            !currentpack['problems'].empty? or !currentpack['requests_from'].empty? or !currentpack['requests_to'].empty?)
      end
      @packages << currentpack
    end

    render json: {packages: @packages, projects: @develprojects.keys}
  end


  def change_role
    if params[:package].blank?
      target = Project.find_by_name!(params[:id])
    else
      target = Package.find_by_project_and_name(params[:id], params[:package])
    end

    if login = params[:user]
      object = User.get_by_login(login)
    elsif title = params[:group]
      object = Group.get_by_title(title)
    else
      raise MissingParameterError, "Neither user nor group given"
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
    render json: {status: 'ok'}
  end

  protected

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

  def project_status_set_version(p)
    ret = {}
    ret['version'] = p.version
    if p.upstream_version
      begin
        gup = Gem::Version.new(p.version)
        guv = Gem::Version.new(p.upstream_version)
      rescue ArgumentError
        # if one of the versions can't be parsed we simply can't say
      end
      
      if gup && guv && gup < guv
        ret['upstream_version'] = p.upstream_version
        ret['upstream_url'] = p.upstream_url
      end
    end
    ret
  end

end
