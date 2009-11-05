class PublicController < ApplicationController
  skip_before_filter :extract_user

  # GET /public/:prj/:repo/:arch/:pkg
  def build
    valid_http_methods :get
    
    unless (params[:prj] and params[:pkg] and params[:repo] and params[:arch])
      render_error :status => 404, :errorcode => "unknown_resource",
        :message => "unknown resource '#{request.path}'"
      return
    end

    path = unshift_public(request.path)
    path << "?#{request.query_string}" unless request.query_string.empty?

    if params[:view]
      unless %w(names cpio cache binaryversions).include?(params[:view])
        render_error :status => 400, :errorcode => "missing_parameter",
          :message => "query parameter 'view' has to be either names, cpio or cache"
        return
      end

      if %w{names binaryversions}.include?(params[:view])
        forward_data path
      else
        headers.update(
          'Content-Type' => 'application/x-cpio'
        )
        render_stream(Net::HTTP::Get.new(path))
      end
    else
      forward_data path
    end
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

  # GET /public/source/:prj/_config
  def project_config
    valid_http_methods :get
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    forward_data path
  end

  # GET /public/source/:prj/:pkg
  def package_index
    valid_http_methods :get
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    forward_data path
  end

  # GET /public/source/:prj/:pkg/_meta
  def package_meta
    valid_http_methods :get
    if pkg = DbPackage.find_by_project_and_name(params[:prj], params[:pkg])
      render :text => pkg.to_axml, :content_type => 'text/xml'
    else
      render_error :message => "Unknown package "+params[:prj]+'/'+params[:pkg],
        :status => 404, :errorcode => "unknown_package"
    end
  end

  # GET /public/source/:prj/:pkg/:file
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

    render_stream Net::HTTP::Get.new(path+build_query_from_hash(params, [:rev]))
  end

  # GET /public/lastevents
  def lastevents
    valid_http_methods :get
    
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?

    render_stream(Net::HTTP::Get.new(path))
  end

  # GET /public/person/:login/_watchlist
  def watchlist
    valid_http_methods :get
    if params[:login]
      login = URI.unescape( params[:login] )
      logger.debug "Generating for user from parameter #{login}"
      @render_user = User.find_by_login( login )
      if ! @render_user 
        logger.debug "User is not valid!"
        render_error :status => 404, :errorcode => 'unknown_user',
          :message => "Unknown user: #{login}"
      else
        render :template => 'person/watchlist'
        # see the corresponding view person/watchlist.rxml that generates a xml
        # response for the caller.
      end
    end
  end

  # GET /public/distributions
  def distributions
    valid_http_methods :get
    render :text => DistributionController.read_distfile, :content_type => "text/xml"
  end

  # GET /public/binary_packages/:project/:package
  def binary_packages
    if (@prj = DbProject.find_by_name params[:project]).blank?
      render_error :status => 404, :errorcode => 'unknown_project'
      return
    end

    if (@pkg = @prj.db_packages.find_by_name params[:package]).blank?
      render_error :status => 404, :errorcode => 'unknown_package'
      return
    end

    distfile = ActiveXML::Node.new(DistributionController.read_distfile)
    binaries = Collection.find :id, :what => 'published/binary', :match => "@project='#{@prj.name}' and @package='#{@pkg.name}'"
    binary_map = Hash.new
    binaries.each do |bin|
      next if bin.arch.to_s == "src"
      binary_map[bin.repository.to_s] ||= Array.new
      binary_map[bin.repository.to_s] << bin
    end

    def scan_distfile(distfile)
      h = HashWithIndifferentAccess.new
      distfile.each_distribution do |dist|
        h["#{dist.project.text()}/#{dist.repository.text()}"] = dist
      end
      return h
    end

    @links = Array.new

    d = scan_distfile(distfile)
    @prj.repositories.find(:all, :include => {:path_elements => {:link => :db_project}}).each do |repo|
      d.each do |key, dist|
        logger.debug sprintf "-- d.each .. key: %s", key
        if repo.path_elements.length == 1 and repo.path_elements[0].to_string == key
          next unless binary_map.has_key? repo.name
          binary = nil
          if binary_map[repo.name].length > 1
            #if package produces more than one binary, try to find one that matches
            #the package name 
            binary = binary_map[repo.name].select {|bin| bin.name == @pkg.name}.first
          end
          
          binary = binary_map[repo.name].first unless binary

          link = {:id => dist.method_missing(:id)}
          if dist.vendor == "opensuse"
            link[:href] = YMP_URL + binary.filepath.sub(%r([^/]+/[^/]+$), binary.name+".ymp")
            link[:type] = "ymp"
            @links << link
          else
            @links << link.merge({:type => binary.method_missing(:type), :arch => binary.arch, :href => DOWNLOAD_URL+binary.filepath})
            repo_href = binary.filepath.sub(%r([^/]+/[^/]+$), @prj.name+".repo")
            @links << {:id => dist.method_missing(:id), :type => "yum", :href => DOWNLOAD_URL+repo_href}
          end
          break
        end
      end
    end

    @binaries = binary_map
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
