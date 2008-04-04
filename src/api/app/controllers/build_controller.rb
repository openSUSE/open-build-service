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
    raise
    if request.get? and (view == "cpio" or view == "cache")
      #stream without authentication
      path = request.path+"?"+request.query_string
      logger.info "streaming #{path}"
      
      headers.update(
          'Transfer-Encoding' => 'chunked',
          'Content-Type' => 'application/octet-stream'
      )

      render :status => 200, :text => Proc.new {|request,output|
        backend_request = Net::HTTP::Get.new(path)
        response = Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write format("%x\r\n", chunk.length)
              output.write chunk
              output.write "\r\n"
            end
            output.write "0\r\n\r\n"
          end
        end
      }
      return
    end

    #authenticate
    return unless extract_user
    pass_to_source
  end
end
