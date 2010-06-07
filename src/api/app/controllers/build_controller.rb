class BuildController < ApplicationController
  skip_before_filter :extract_user, :only => [:package_index]

  def project_index
    @path = request.path
    unless request.query_string.empty?
      @path += '?' + request.query_string
    end

    if request.get?
      forward_data @path
    elsif request.post?
      allowed = false
      allowed = true if permissions.global_project_change

      if not allowed
        #check if user has project modify rights
        allowed = true if permissions.project_change? params[:project]
      end

      if not allowed and not params[:package].nil?
        package_names = nil
        if params[:package].kind_of? Array
          package_names = params[:packge]
        else
          package_names = [params[:package]]
        end

        package_names.each do |pack_name|
          allowed = permissions.package_change? pack_name, params[:project]
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

      #check for cmd parameter
      if params[:cmd].nil?
        render_error :status => 403, :errorcode => "missing_parameter",
          :message => "Missing parameter 'cmd'"
        return
      end

      forward_data @path, :method => :post
      return
    else
      render_error :status => 400, :errorcode => 'illegal_request',
        :message => "Illegal request: #{request.method.to_s.upcase} #{request.path}"
      return
    end
  end

  def buildinfo
    path = "/build/#{params[:project]}/#{params[:repository]}/#{params[:arch]}/#{params[:package]}/_buildinfo"
    unless request.query_string.empty?
      path += '?' + request.query_string
    end

    if request.post?
      response = Suse::Backend.post path, request.raw_post
      send_data( response.body, :type => response.fetch( "Content-Type" ), :disposition => "inline" )
    else
      forward_data path
    end 
  end

  # /build/:prj/:repo/:arch/:pkg
  # GET on ?view=cpio and ?view=cache unauthenticated and streamed
  def package_index
    view = params[:view]
    if request.get? and (view == "cpio" or view == "cache")
      #stream without authentication
      path = request.path+"?"+request.query_string
      logger.info "streaming #{path}"
      
      headers.update(
        'Content-Type' => 'application/x-cpio'
      )

      render :status => 200, :text => Proc.new {|request,output|
        backend_request = Net::HTTP::Get.new(path)
        response = Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write chunk
            end
          end
        end
      }
      return
    end

    #authenticate
    return unless extract_user
    pass_to_source
  end

  # /build/:project/:repository/:arch/:package/:filename
  def file
    valid_http_methods :get
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]
    if pkg and pkg.binarydownload_flags.disabled_for?(params[:repository], params[:arch])
      # check downloader role
      unless @http_user.can_download_binaries?(pkg)
        render_error :status => 403, :errorcode => "download_binary_no_permission",
          :message => "No permission to download binaries from package #{params[:package]}, project #{params[:project]}"
        return
      end
    end

    path = request.path+"?"+request.query_string

    #check if binary exists and for size
    fpath = "/build/"+[:project,:repository,:arch,:package].map {|x| params[x]}.join("/")+request.query_string
    file_list = Suse::Backend.get(fpath)
    regexp = file_list.body.match(/name=["']#{Regexp.quote params[:filename]}["'].*size=["']([^"']*)["']/)
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
      forward_data path
    end
  end

  def logfile
    valid_http_methods :get
    path = request.path
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]
    #logfile controled by binarydownload_flags and download_binary permission
    if pkg and pkg.binarydownload_flags.disabled_for?(params[:repository], params[:arch]) and not @http_user.can_download_binaries?(pkg)
      render_error :status => 403, :errorcode => "download_binary_no_permission",
      :message => "No permission to download logfile for package #{params[:package]}, project #{params[:project]}"
      return
    end
    forward_data path
  end

  def result
    valid_http_methods :get
    path = request.path
    prj = DbProject.find_by_name params[:project]
    if prj and prj.privacy_flags.disabled_for?(params[:repository], params[:arch]) and not @http_user.can_private_view?(prj)
#     render_error :status => 403, :errorcode => "private_view_no_permission",
#     :message => "No permission to view project #{params[:project]}"
      render_ok
      return
    end
    pkg = DbPackage.find_by_project_and_name params[:project], params[:package]
    if pkg and pkg.privacy_flags.disabled_for?(params[:repository], params[:arch]) and not @http_user.can_private_view?(pkg)
      render_ok
      return
    end
    forward_data path
  end

end
