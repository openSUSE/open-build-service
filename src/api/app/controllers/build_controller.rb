class BuildController < ApplicationController

  def index
    valid_http_methods :get, :post, :put

    # for permission check
    if params[:package] and params[:package] != "_repository"
      pkg = DbPackage.get_by_project_and_name( params[:project], params[:package], use_source=false )
    else
      prj = DbProject.get_by_name params[:project]
    end

    # returns <binarylist /> on unkown package !
    # normally we'd do e.g.: raise DbPackage::ReadAccessError.new "" unless pkg

# FIXME2.2: This breaks repository download and no test case is showing why it is needed.
#    if prj and params[:package] and pkg.nil?
#      render :text => "<binarylist />", :content_type => "text/xml"
#      return
#    end

    pass_to_backend 
  end

  def project_index
    valid_http_methods :get, :post, :put

    prj = nil
    unless params[:project] == "_dispatchprios"
      prj = DbProject.get_by_name params[:project]
    end

    path = request.path

    if not request.query_string.blank?
      path += '?' + request.query_string
    elsif not request.env["rack.request.form_vars"].blank?
      path += '?' + request.env["rack.request.form_vars"]
    end
    if request.get?
      pass_to_backend path
      return
    elsif request.post?
      allowed = false
      allowed = true if permissions.global_project_change

      #check for cmd parameter
      if params[:cmd].nil?
        render_error :status => 400, :errorcode => "missing_parameter",
          :message => "Missing parameter 'cmd'"
        return
      end

      unless ["wipe", "restartbuild", "killbuild", "abortbuild", "rebuild"].include? params[:cmd]
        render_error :status => 400, :errorcode => "illegal_request",
          :message => "unsupported POST command #{params[:cmd]} to #{request.request_uri}"
        return
      end

      if not allowed
        prj = DbProject.get_by_name( params[:project] ) 

        #check if user has project modify rights
        allowed = true if permissions.project_change? prj
      end

      if not allowed and not params[:package].nil?
        package_names = nil
        if params[:package].kind_of? Array
          package_names = params[:package]
        else
          package_names = [params[:package]]
        end
        package_names.each do |pack_name|
          pkg = DbPackage.find_by_project_and_name( prj.name, pack_name ) 
          if pkg.nil?
            allowed = permissions.project_change? prj
            if not allowed
              render_error :status => 403, :errorcode => "execute_cmd_no_permission",
                :message => "No permission to execute command on package #{pack_name} in project #{prj.name}"
              return
            end
          else
            allowed = permissions.package_change? pkg
            if not allowed
              render_error :status => 403, :errorcode => "execute_cmd_no_permission",
                :message => "No permission to execute command on package #{pack_name}"
              return
            end
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
      if @http_user.is_admin?
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
    pkg = DbPackage.get_by_project_and_name params[:project], params[:package], use_source=false

    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_buildinfo"
    unless request.query_string.empty?
      path += '?' + request.query_string
    end

    pass_to_backend path
  end

  # /build/:prj/:repo/:arch/:pkg
  def package_index
    valid_http_methods :get
    required_parameters :project, :repository, :arch, :package

    # read access permission check
    if params[:package] == "_repository"
      prj = DbProject.get_by_name params[:project], use_source=false
    else
      pkg = DbPackage.get_by_project_and_name params[:project], params[:package], use_source=false
    end

    pass_to_backend
  end

  # /build/:project/:repository/:arch/:package/:filename
  def file
    valid_http_methods :get, :delete
    required_parameters :project, :repository, :arch, :package, :filename

    # read access permission check
    if params[:package] == "_repository"
      prj = DbProject.get_by_name params[:project]
    else
      pkg = DbPackage.get_by_project_and_name params[:project], params[:package], use_source=false
      prj = pkg.db_project
    end

    # FIXME2.2:
    # binary download can be only supported project wide. We need to disallow it as per package
    # setting, now that it is wanted as security feature
    if prj.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(prj)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    path = request.path+"?"+request.query_string

    if request.delete?
      unless permissions.project_change? params[:project]
        render_error :status => 403, :errorcode => "delete_binary_no_permission",
          :message => "No permission to delete binaries from project #{params[:project]}"
        return
      end

      if params[:package] == "_repository"
        pass_to_backend
      else
        render_error :status => 400, :errorcode => "invalid_operation",
          :message => "Delete operation of build results is not allowed"
      end

      return
    end

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

    # for permission check
    pkg = DbPackage.get_by_project_and_name params[:project], params[:package]

    # FIXME2.2:
    # binary download can be only supported project wide. We need to disallow it as per package
    # setting, now that it is wanted as security feature
    if pkg.db_project.disabled_for?('binarydownload', params[:repository], params[:arch]) and not @http_user.can_download_binaries?(pkg.db_project)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
      return
    end

    pass_to_backend
  end

  def result
    valid_http_methods :get
    # for permission check
    prj = DbProject.get_by_name params[:project]

    pass_to_backend
  end

end
