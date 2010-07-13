class BuildController < ApplicationController

  def project_index
    valid_http_methods :get, :post, :put
    prj = DbProject.find_by_name params[:project]

    # ACL(project_index): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if prj and prj.disabled_for?('access', nil, nil) and not @http_user.can_access?(prj)
      render_error :status => 404, :errorcode => 'unknown_project',
      :message => "Unknown project '#{params[:project]}'"
      return
    end

    path = request.path
    unless request.query_string.empty?
      path += '?' + request.query_string
    end

    if request.get?
      pass_to_backend path
    elsif request.post?
      allowed = false
      allowed = true if permissions.global_project_change

      #check for cmd parameter
      if params[:cmd].nil?
        render_error :status => 400, :errorcode => "missing_parameter",
          :message => "Missing parameter 'cmd'"
        return
      end

      unless ["wipe", "restartbuild", "killbuild", "rebuild"].include? params[:cmd]
        render_error :status => 400, :errorcode => "illegal_request",
          :message => "illegal POST request to #{request.request_uri}"
        return
      end

      if not allowed
        prj = DbProject.find_by_name( params[:project] ) 
        if prj.nil?
          render_error :status => 404, :errorcode => "not_found",
            :message => "Project does not exist #{params[:project]}"
          return
        end

        #check if user has project modify rights
        allowed = true if permissions.project_change? prj
      end

      if not params[:package].nil?
        package_names = nil
        if params[:package].kind_of? Array
          package_names = params[:package]
        else
          package_names = [params[:package]]
        end
        package_names.each do |pack_name|
          pkg = DbPackage.find_by_project_and_name( prj.name, pack_name ) 
          if pkg.nil?
            render_error :status => 404, :errorcode => "not_found",
              :message => "Package does not exist #{pack_name}"
            return
          end
          allowed = permissions.package_change? pkg
          if not allowed
            render_error :status => 403, :errorcode => "execute_cmd_no_permission",
              :message => "No permission to execute command on package #{pack_name}"
            return
          end
        end
      end

      if not allowed
        render_error :status => 403, :errorcode => "execute_cmd_no_permission",
          :message => "No permission to execute command on project #{params[:project]}"
        return
      end

      pass_to_backend path
      return
    elsif request.put? 
      if  @http_user.is_admin?
        pass_to_backend path
      else
        render_error :status => 403, :errorcode => "execute_cmd_no_permission",
          :message => "No permission to execute command on project #{params[:project]}"
      end
      return
    else
      render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: #{request.method.to_s.upcase} #{request.path}"
      return
    end
  end

  def buildinfo
    valid_http_methods :get, :post
    required_parameters :project, :repository, :arch, :package
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]

    # ACL(buildinfo): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if pkg.disabled_for?('access', params[:repository], params[:arch]) and not @http_user.can_access?(pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
      :status => 404, :errorcode => "unknown_package"
      return
    end

    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_buildinfo"
    unless request.query_string.empty?
      path += '?' + request.query_string
    end

    pass_to_backend path
  end

  # /build/:prj/:repo/:arch/:pkg
  # GET on ?view=cpio and ?view=cache unauthenticated and streamed
  def package_index
    valid_http_methods :get
    required_parameters :project, :repository, :arch, :package
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]

    # ACL(package_index): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if pkg.disabled_for?('access', params[:repository], params[:arch]) and not @http_user.can_access?(pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
      :status => 404, :errorcode => "unknown_package"
      return
    end
    pass_to_backend
  end

  # /build/:project/:repository/:arch/:package/:filename
  def file
    valid_http_methods :get
    required_parameters :project, :repository, :arch, :package, :filename
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]

    # ACL(file): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if pkg.disabled_for?('access', params[:repository], params[:arch]) and not @http_user.can_access?(pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
      :status => 404, :errorcode => "unknown_package"
      return
    end

    # ACL(file): acces should be handled different
    if pkg.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(pkg)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    path = request.path+"?"+request.query_string

    regexp = nil
    # if there is a query, we can't assume it's a simple download, so better leave out the logic (e.g. view=fileinfo)
    unless request.query_string
      #check if binary exists and for size
      fpath = "/build/"+[:project,:repository,:arch,:package].map {|x| params[x]}.join("/")
      file_list = Suse::Backend.get(fpath)
      regexp = file_list.body.match(/name=["']#{Regexp.quote params[:filename]}["'].*size=["']([^"']*)["']/)
    end
    if regexp
      fsize = regexp[1]
      logger.info "streaming #{path}"

      c_type = case params[:filename].split(/\./)[-1]
               when "rpm"
                 "application/x-rpm"
               when "deb"
                 "application/x-deb"
               when "iso"
                 "application/x-cd-image"
               else
                 "application/octet-stream"
               end

      headers.update(
        'Content-Disposition' => %(attachment; filename="#{params[:filename]}"),
        'Content-Type' => c_type,
        'Transfer-Encoding' => 'binary',
        'Content-Length' => fsize
      )
      
      render :status => 200, :text => Proc.new {|request,output|
        backend_request = Net::HTTP::Get.new(path)
        Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write(chunk)
            end
          end
        end
      }
    else
      pass_to_backend path
    end
  end

  def logfile
    valid_http_methods :get
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]

    # ACL(logfile): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if pkg and pkg.disabled_for?('access', params[:repository], params[:arch]) and not @http_user.can_access?(pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
      :status => 404, :errorcode => "unknown_package"
      return
    end

    # ACL(logfile): binarydownload denies logfile acces
    if pkg and pkg.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(pkg)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download logfile for package #{params[:package]}, project #{params[:project]}"
      return
    end
    pass_to_backend
  end

  def result
    valid_http_methods :get
    prj = DbProject.find_by_name params[:project]
    if prj.nil?
      pass_to_backend
      return
    end
    pkg = prj.find_package params[:package]

    # ACL(result): in case of access, project is really hidden, e.g. does not get listed, accessing says project is not existing
    if prj and prj.disabled_for?('access', nil, nil) and not @http_user.can_access?(prj)
      render_error :status => 404, :errorcode => 'unknown_project',
      :message => "Unknown project '#{params[:project]}'"
      return
    end

    # ACL(result): binarydownload on for prj means behave like a binary only project
    if prj and prj.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(prj)
      render_ok
      return
    end

    # ACL(result): in case of access, package is really hidden, e.g. does not get listed, accessing says package is not existing
    if pkg and pkg.disabled_for?('access', nil, nil) and not @http_user.can_access?(pkg)
      render_error :message => "Unknown package '#{params[:project]}/#{params[:package]}'",
      :status => 404, :errorcode => "unknown_package"
      return
    end

    # ACL(result): privacy on means again not listing files
    if pkg and pkg.enabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(pkg)
      render_ok
      return
    end
    pass_to_backend
  end

end
