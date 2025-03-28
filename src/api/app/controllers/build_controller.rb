class BuildController < ApplicationController
  skip_before_action :extract_user, only: [:scmresult]
  skip_before_action :require_login, only: [:scmresult]

  before_action :require_scmsync_host_check, only: [:scmresult]

  def index
    # for read access and visibility permission check
    if params[:package] && %w[_repository _jobhistory].exclude?(params[:package])
      Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_multibuild: true)
    else
      Project.get_by_name(params[:project])
    end

    if request.get?
      pass_to_backend
      return
    end

    if User.admin_session?
      # check for a local package instance
      Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_project_links: false)
      pass_to_backend
    else
      render_error status: 403, errorcode: 'execute_cmd_no_permission',
                   message: 'Upload of binaries is only permitted for administrators'
    end
  end

  def project_index
    prj = nil
    prj = Project.get_by_name(params[:project]) unless params[:project] == '_dispatchprios'

    if request.get?
      pass_to_backend
    elsif request.post?
      # check if user has project modify rights
      allowed = false
      allowed = true if permissions.global_project_change
      allowed = true if permissions.project_change?(prj)

      # check for cmd parameter
      raise MissingParameterError, "Missing parameter 'cmd'" if params[:cmd].nil?

      unless %w[wipe restartbuild killbuild abortbuild rebuild unpublish sendsysrq].include?(params[:cmd])
        render_error status: 400, errorcode: 'illegal_request',
                     message: "unsupported POST command #{params[:cmd]} to #{request.url}"
        return
      end

      unless prj.instance_of?(Project)
        render_error status: 403, errorcode: 'readonly_error',
                     message: "The project #{params[:project]} is a remote project and therefore readonly."
        return
      end

      if !allowed && !params[:package].nil?
        [params[:package]].flatten.each do |pack_name|
          pkg = Package.find_by_project_and_name(prj.name, Package.multibuild_flavor(pack_name))
          if pkg.nil?
            allowed = permissions.project_change?(prj)
            unless allowed
              render_error status: 403, errorcode: 'execute_cmd_no_permission',
                           message: "No permission to execute command on package #{pack_name} in project #{prj.name}"
              return
            end
          else
            allowed = permissions.package_change?(pkg)
            unless allowed
              render_error status: 403, errorcode: 'execute_cmd_no_permission',
                           message: "No permission to execute command on package #{pack_name}"
              return
            end
          end
        end
      end

      unless allowed
        render_error status: 403, errorcode: 'execute_cmd_no_permission',
                     message: "No permission to execute command on project #{params[:project]}"
        return
      end

      pass_to_backend
    elsif request.put?
      if User.admin_session?
        pass_to_backend
      else
        render_error status: 403, errorcode: 'execute_cmd_no_permission',
                     message: "No permission to execute command on project #{params[:project]}"
      end
    else
      render_error status: 400, errorcode: 'illegal_request',
                   message: "Illegal request: #{request.method.to_s.upcase} #{request.path}"
    end
    nil
  end

  def buildinfo
    required_parameters :project, :repository, :arch, :package
    # just for permission checking
    if request.post? && Package.striping_multibuild_suffix(params[:package]) == '_repository'
      # for osc local package build in this repository
      Project.get_by_name(params[:project])
    else
      Package.get_by_project_and_name(params[:project], params[:package], use_source: false, follow_multibuild: true)
    end

    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_buildinfo"
    path += "?#{request.query_string}" unless request.query_string.empty?

    # we need to protect broken osc versions, which try to handle hdrmd5, but have a broken
    # implementation since python 3. this would break all local builds otherwise with unfixed
    # osc python 3 versions
    # Fixed for osc: https://github.com/openSUSE/osc/pull/958
    if request.user_agent.present? && request.user_agent[0..5] == 'osc/0.' && request.user_agent[6..].to_i < 175
      path += request.query_string.empty? ? '?' : '&'
      path += 'striphdrmd5'
    end

    pass_to_backend(path)
  end

  # /build/:project/:repository/:arch/_builddepinfo
  def builddepinfo
    required_parameters :project, :repository, :arch

    # just for permission checking
    Project.get_by_name(params[:project])

    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/_builddepinfo"
    path += "?#{request.query_string}" unless request.query_string.empty?

    pass_to_backend(path)
  end

  def logfile
    # for permission check
    pkg = Package.get_by_project_and_name(params[:project], params[:package], follow_multibuild: true)

    if pkg.instance_of?(Package) && pkg.project.disabled_for?('binarydownload', params[:repository], params[:arch]) &&
       !User.possibly_nobody.can_download_binaries?(pkg.project)
      render_error status: 403, errorcode: 'download_binary_no_permission',
                   message: "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    pass_to_backend
  end

  def result
    required_parameters :project

    # this route is mainly for checking submissions to a target project
    return result_lastsuccess if params.key?(:lastsuccess)

    # for permission check
    Project.get_by_name(params[:project])

    pass_to_backend
  end

  def scmresult
    # permission handling is done in the scm bridge
    pass_to_backend
  end

  def result_lastsuccess
    required_parameters :package, :pathproject

    pkg = Package.get_by_project_and_name(params[:project], params[:package],
                                          use_source: false, follow_multibuild: true)
    raise RemoteProjectError, 'The package lifes in a remote project, this is not supported atm' unless pkg

    tprj = Project.get_by_name(params[:pathproject])
    multibuild_package = params[:package] if params[:package].include?(':')
    bs = PackageBuildStatus.new(pkg).result(target_project: tprj, srcmd5: params[:srcmd5], multibuild_pkg: multibuild_package)
    @result = []
    bs.each do |repo, status|
      archs = status.map do |arch, archstat|
        if archstat[:missing].blank?
          [arch, archstat[:result], nil]
        else
          [arch, archstat[:result], archstat[:missing].join(',')]
        end
      end
      @result << [repo, archs]
    end
    render xml: render_to_string(partial: 'lastsuccess')
  end
end
