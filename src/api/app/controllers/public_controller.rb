class PublicController < ApplicationController
  skip_before_filter :extract_user

  # GET /public/:prj/:repo/:arch/:pkg?:view
  def build
    valid_http_methods :get
    
    unless (params[:prj] and params[:pkg] and params[:repo] and params[:arch])
      render_error :status => 404, :errorcode => "unknown_resource",
        :message => "unknown resource '#{request.path}'"
      return
    end

    unless %w(cpio cache).include?(params[:view])
      render_error :status => 400, :errorcode => "missing_parameter",
        :message => "query parameter 'view' has to be either cpio or cache"
      return
    end

    path = unshift_public(request.path)
    path << "?#{request.query_string}"

    headers.update(
      'Content-Type' => 'application/x-cpio'
    )

    render_stream(Net::HTTP::Get.new(path))
  end

  # GET /public/source/:prj/_meta
  def project_meta
    valid_http_methods :get

    if prj = DbProject.find_by_name(params[:prj])
      render :text => prj.to_axml, :content_type => 'text/xml'
    else
      render_error :message => "Unknown project '#{params[:prj]}'",
        :status => 404, :errorcode => "unknown_project"
    end
  end

  def project_config
    valid_http_methods :get
    path = unshift_public(request.path)
    forward_data path
  end

  def source_file
    valid_http_methods :get
    path = unshift_public(request.path)
    prj, pkg, file = params[:prj], params[:pkg], params[:file]

    fpath = "/source/#{params[:prj]}/#{params[:pkg]}" + build_query_from_hash(params, [:rev])
    if flist = Suse::Backend.get(fpath)
      if regexp = flist.body.match(/name=["']#{Regexp.quote file}["'].*size=["']([^"']*)["']/)
        headers.update('Content-Length' => regexp[1])
      end
    end

    headers.update(
      'Content-Disposition' => %(attachment; filename="#{file}"),
      'Content-Type' => 'application/octet-stream',
      'Transfer-Encoding' => 'binary'
    )

    render_stream Net::HTTP::Get.new(path)
  end

  def lastevents
    valid_http_methods :get
    
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?

    render_stream(Net::HTTP::Get.new(path))
  end

  private

  # removes /private prefix from path
  def unshift_public(path)
    if path.match %r{/public(.*)}
      return $1
    else
      return path
    end
  end

  def render_stream(backend_request)
    logger.info "streaming #{backend_request.path}"
    render :status => 200, :text => Proc.new {|request,output|
      response = Net::HTTP.start(SOURCE_HOST,SOURCE_PORT) do |http|
        http.request(backend_request) do |response|
          response.read_body do |chunk|
            output.write chunk
          end
        end
      end
    }
  end
end
