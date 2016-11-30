class PublicController < ApplicationController
  include PublicHelper

  # we need to fall back to _nobody_ (_public_)
  before_action :extract_user_public, :set_response_format_to_xml
  skip_before_action :extract_user
  skip_before_action :require_login

  def index
    redirect_to controller: 'about', action: 'index'
  end

  # GET /public/build/:project/:repository/:arch/:package
  def build
    required_parameters :project

    # project visible/known ?
    Project.get_by_name(params[:project])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?

    pass_to_backend path
  end

  # GET /public/configuration
  # GET /public/configuration.xml
  # GET /public/configuration.json
  def configuration_show
    @configuration = ::Configuration.first

    respond_to do |format|
      format.xml  { render xml: @configuration.render_xml }
      format.json { render json: @configuration.to_json }
    end
  end

  # GET /public/source/:project/_meta
  def project_meta
    # project visible/known ?
    Project.get_by_name(params[:project])

    pass_to_backend unshift_public(request.path_info)
  end

  # GET /public/source/:project
  def project_index
    # project visible/known ?
    @project = Project.get_by_name(params[:project])
    path = unshift_public(request.path_info)
    if params[:view] == 'info'
      # nofilename since a package may have no source access
      if params[:nofilename] && params[:nofilename] != '1'
        render_error status: 400, errorcode: 'parameter_error', message: 'nofilename is not allowed as parameter'
        return
      end
      # path has multiple package= parameters
      path += '?' + request.query_string
      path += '&nofilename=1' unless params[:nofilename]
    elsif params[:view] == 'verboseproductlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/verboseproductlist'
      return
    elsif params[:view] == 'productlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/productlist'
      return
    else
      path += '?expand=1&noorigins=1' # to stay compatible to OBS <2.4
    end
    pass_to_backend path
  end

  # GET /public/source/:project/_config
  # GET /public/source/:project/_pubkey
  def project_file
    # project visible/known ?
    Project.get_by_name(params[:project])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:project/:package
  def package_index
    check_package_access(params[:project], params[:package])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend path
  end

  # GET /public/source/:project/:package/_meta
  def package_meta
    check_package_access(params[:project], params[:package], false)

    pass_to_backend unshift_public(request.path_info)
  end

  # GET /public/source/:project/:package/:filename
  def source_file
    file = params[:filename]

    check_package_access(params[:project], params[:package])

    path = "/source/#{CGI.escape(params[:project])}/#{CGI.escape(params[:package])}/#{CGI.escape(file)}"

    path += build_query_from_hash(params, [:rev])
    volley_backend_path(path) unless forward_from_backend(path)
  end

  # GET /public/distributions
  def distributions
    @distributions = Distribution.all_as_hash

    render 'distributions/index'
  end

  # GET /public/request/:number
  def show_request
    required_parameters :number
    req = BsRequest.find_by_number!(params[:number])
    render xml: req.render_xml()
  end

  # GET /public/binary_packages/:project/:package
  def binary_packages
    check_package_access(params[:project], params[:package], false)
    @pkg = Package.find_by_project_and_name(params[:project], params[:package])

    begin
       binaries = Collection.find :id, what: 'published/binary', match: "@project='#{params[:project]}' and @package='#{params[:package]}'"
    rescue
      render_error status: 400, errorcode: 'search_failure', message: "The search can't get executed."
      return
    end

    binary_map = Hash.new
    binaries.each do |bin|
      repo_string = bin.value(:repository)
      next if bin.value(:arch) == 'src'
      next unless bin.value(:filepath)
      binary_map[repo_string] ||= Array.new
      binary_map[repo_string] << bin
    end

    @binary_links = {}
    @pkg.project.repositories.includes({path_elements: {link: :project}}).each do |repo|
      repo.path_elements.each do |pe|
        # NOTE: we do not follow indirect path elements here, since most installation handlers
        #       do not support it (exception zypp via ymp files)
        dist = Distribution.find_by_project_and_repository(pe.link.project.name, pe.link.name)
        next unless dist
        unless binary_map[repo.name].blank?
          dist_id = dist.id
          @binary_links[dist_id] ||= {}
          binary = binary_map[repo.name].select {|bin| bin.value(:name) == @pkg.name}.first
          if binary && dist.vendor == 'openSUSE'
            @binary_links[dist_id][:ymp] = { url: ymp_url(File.join(@pkg.project.name, repo.name, @pkg.name+'.ymp') ) }
          end

          @binary_links[dist_id][:binary] ||= []
          binary_map[repo.name].each do |b|
            binary_type = b.value(:type)
            # filepath is historic and contains unfortunatly the old repo mapping already.
            # So we have to revert this here...
            filepath=b.value(:filepath)
            # having both gsub! in one line can crash with some ruby builds
            filepath.gsub!(/:\//, ":")
            filepath.gsub!(/^[^\/]*\/[^\/]*\//, '')

            @binary_links[dist_id][:binary] << {type: binary_type, arch: b.value(:arch), url: repo.download_url(filepath)}
            if @binary_links[dist_id][:repository].blank?
              repo_filename = binary_type == 'rpm' ? "#{@pkg.project.name}.repo" : ''
              @binary_links[dist_id][:repository] ||= { url: repo.download_url(repo_filename) }
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

  def extract_user_public
    # to become _public_ special user
    if ::Configuration.anonymous
      load_nobody
      return true
    end
    logger.error 'No public access is configured'
    render_error( message: 'No public access is configured', status: 401 )
    false
  end

  def check_package_access(project, package, use_source = true)
    # don't use the cache for use_source
    if use_source
      begin
        Package.get_by_project_and_name(project, package)
      rescue ForbidsAnonymousUsers::AnonymousUser
        raise Package::ReadSourceAccessError, "#{project} / #{package} "
      end
      return
    end

    # generic access checks
    key = 'public_package:' + project + ':' + package
    allowed = Rails.cache.fetch(key, expires_in: 30.minutes) do
      begin
        Package.get_by_project_and_name(project, package, use_source: false)
        true
      rescue Exception
        false
      end
    end
    raise Package::UnknownObjectError, "#{project} / #{package} " unless allowed
  end
end
