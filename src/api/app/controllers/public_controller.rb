class PublicController < ApplicationController
  include PublicHelper
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
        pass_to_backend path
      else
        headers.update(
          'Content-Type' => 'application/x-cpio'
        )
        render_stream(Net::HTTP::Get.new(path))
      end
    else
      pass_to_backend path
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

  # GET /public/source/:prj
  def project_index
    valid_http_methods :get
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:prj/_config
  def project_config
    valid_http_methods :get
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:prj/:pkg
  def package_index
    valid_http_methods :get
    path = unshift_public(request.path)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
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
    project_name = params[:prj]
    package_name = params[:pkg]
    file = params[:file]

    path = "/source/#{project_name}/#{package_name}/#{file}"

    if request.get?
      path += build_query_from_hash(params, [:rev])
      pass_to_backend path
      return
    end
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
      render_error :status => 404, :errorcode => 'unknown_project', :message => "The requested project #{params[:project]} does not exist."
      return
    end

    if (@pkg = @prj.db_packages.find_by_name params[:package]).blank?
      render_error :status => 404, :errorcode => 'unknown_package', :message => "The requested project #{params[:project]} does not exist."
      return
    end

    distfile = ActiveXML::XMLNode.new(DistributionController.read_distfile)
    begin
       binaries = Collection.find :id, :what => 'published/binary', :match => "@project='#{@prj.name}' and @package='#{@pkg.name}'"
    rescue
      render_error :status => 400, :errorcode => 'search_failure', :message => "The search can't get executed."
      return
    end

    binary_map = Hash.new
    binaries.each do |bin|
      repo_string = bin.repository.to_s
      next if bin.arch.to_s == "src"
      binary_map[repo_string] ||= Array.new
      binary_map[repo_string] << bin
    end

    def scan_distfile(distfile)
      h = HashWithIndifferentAccess.new
      distfile.each_distribution do |dist|
        h["#{dist.project.text()}/#{dist.repository.text()}"] = dist
        h["#{dist.project.text()}"] = dist
        h["#{dist.reponame.text()}"] = dist
      end
      return h
    end
    d = scan_distfile(distfile)

    @binary_links = {}
    @prj.repositories.find(:all, :include => {:path_elements => {:link => :db_project}}).each do |repo|
      # TODO: this code doesnt handle path elements and layering
      # TODO: walk the path and find the base repos? is that desired?
      dist = d[repo.name]
      if dist
        unless binary_map[repo.name].blank?
          dist_id = dist.method_missing(:id)
          @binary_links[dist_id] ||= {}
          binary = binary_map[repo.name].select {|bin| bin.name == @pkg.name}.first
          if binary and dist.vendor == "openSUSE"
            @binary_links[dist_id][:ymp] = { :url => ymp_url(File.join(@prj.name, repo.name, @pkg.name+".ymp") ) }
          end

          @binary_links[dist_id][:binary] ||= []
          binary_map[repo.name].each do |binary|
            binary_type = binary.method_missing(:type)
            @binary_links[dist_id][:binary] << {:type => binary_type, :arch => binary.arch, :url => download_url(binary.filepath)}
            if @binary_links[dist_id][:repository].blank?
              repo_filename = (binary_type == 'rpm') ? "#{@prj.name}.repo" : ''
              repository_path = File.join(@prj.download_name, repo.name, repo_filename)
              @binary_links[dist_id][:repository] ||= { :url => download_url(repository_path) }
            end
          end
          #
        end
      end
    end
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
        begin
          http.request(backend_request) do |response|
            response.read_body do |chunk|
              output.write chunk
            end
          end
        rescue Timeout::Error
          logger.info "catched TIMEOUT: #{backend_request.path}"
        end
      end
    }
  end
end
