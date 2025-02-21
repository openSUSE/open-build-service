class PublicController < ApplicationController
  include PublicHelper
  include ValidationHelper

  # we need to fall back to _nobody_ (_public_)
  before_action :extract_user_public, :set_response_format_to_xml, :set_influxdb_data_interconnect
  skip_before_action :extract_user
  skip_before_action :require_login

  # GET /public/build/:project/:repository/:arch/:package
  def build
    required_parameters :project

    if params[:project] == '_result'
      pass_to_backend("/build/_result#{build_query_from_hash(params, %i[scmrepository scmbranch locallink multibuild lastbuild code])}")
      return
    end
    # project visible/known ?
    Project.get_by_name(params[:project])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?

    pass_to_backend(path)
  end

  # GET /public/configuration
  # GET /public/configuration.xml
  # GET /public/configuration.json
  def configuration_show
    @configuration = ::Configuration.fetch

    respond_to do |format|
      format.xml  { render xml: @configuration.render_xml }
      format.json { render json: @configuration.to_json }
    end
  end

  # GET /public/source/:project/_meta
  def project_meta
    # project visible/known ?
    Project.get_by_name(params[:project])

    path = unshift_public(request.path_info)
    # we should do this via user agent instead, but BSRPC is not only used for interconnect.
    # so we do not have a way atm.
    path += '?interconnect=1'
    pass_to_backend(path)
  end

  # GET /public/source/:project
  def project_index
    # project visible/known ?
    @project = Project.get_by_name(params[:project])
    path = unshift_public(request.path_info)
    case params[:view]
    when 'info'
      # nofilename since a package may have no source access
      if params[:nofilename] && params[:nofilename] != '1'
        render_error status: 400, errorcode: 'parameter_error', message: 'nofilename is not allowed as parameter'
        return
      end
      # path has multiple package= parameters
      path += "?#{request.query_string}"
      path += '&nofilename=1' unless params[:nofilename]
    when 'verboseproductlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/verboseproductlist', formats: [:xml]
      return
    when 'productlist'
      @products = Product.all_products(@project, params[:expand])
      render 'source/productlist', formats: [:xml]
      return
    else
      path += '?expand=1&noorigins=1' # to stay compatible to OBS <2.4
    end
    pass_to_backend(path)
  end

  # GET /public/source/:project/_config
  # GET /public/source/:project/_keyinfo
  # GET /public/source/:project/_pubkey
  def project_file
    # project visible/known ?
    Project.get_by_name(params[:project])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend(path)
  end

  # GET /public/source/:project/:package
  def package_index
    check_package_access(params[:project], params[:package])

    path = unshift_public(request.path_info)
    path += "?#{request.query_string}" unless request.query_string.empty?
    pass_to_backend(path)
  end

  # GET /public/source/:project/:package/_meta
  def package_meta
    check_package_access(params[:project], params[:package], use_source: false)

    path = unshift_public(request.path_info)
    # we should do this via user agent instead, but BSRPC is not only used for interconnect.
    # so we do not have a way atm.
    path += '?interconnect=1'
    pass_to_backend(path)
  end

  # GET /public/source/:project/:package/:filename
  def source_file
    if params[:rev].present? && params[:rev].length >= 32 &&
       !Package.exists_by_project_and_name(params[:project], params[:package])
      prj = Project.find_by_name(params[:project])
      # automatic fallback
      params[:deleted] = '1' unless prj && prj.scmsync.present?
    end

    if params[:deleted].present?
      validate_read_access_of_deleted_package(params[:project], params[:package])
    else
      check_package_access(params[:project], params[:package])
    end

    path = Package.source_path(params[:project], params[:package], params[:filename])
    path += build_query_from_hash(params, %i[rev limit expand deleted])
    volley_backend_path(path) unless forward_from_backend(path)
  end

  # GET /public/distributions
  def distributions
    @distributions = Distribution.local

    render 'distributions/index'
  end

  # GET /public/request/:number
  def show_request
    required_parameters :number
    req = BsRequest.find_by_number!(params[:number])
    render xml: req.render_xml
  end

  # GET /public/binary_packages/:project/:package
  def binary_packages
    check_package_access(params[:project], params[:package], use_source: false)
    @pkg = Package.find_by_project_and_name(params[:project], params[:package])

    begin
      binaries = Xmlhash.parse(Backend::Api::Search.published_binaries_for_package(params[:project], params[:package]))
    rescue Backend::Error
      render_error status: 400, errorcode: 'search_failure', message: "The search can't get executed."
      return
    end

    binary_map = {}
    binaries.elements('binary') do |bin|
      repo_string = bin['repository']
      next if bin.value(:arch) == 'src'
      next unless bin['filepath']

      binary_map[repo_string] ||= []
      binary_map[repo_string] << bin
    end

    @binary_links = {}
    @pkg.project.repositories.includes(path_elements: { link: :project }).find_each do |repo|
      repo.path_elements.each do |pe|
        # NOTE: we do not follow indirect path elements here, since most installation handlers
        #       do not support it (exception zypp via ymp files)
        dist = Distribution.find_by_project_and_repository(pe.link.project.name, pe.link.name)
        next unless dist
        next if binary_map[repo.name].blank?

        dist_id = dist.id
        @binary_links[dist_id] ||= {}
        binary = binary_map[repo.name].find { |bin| bin.value(:name) == @pkg.name }
        @binary_links[dist_id][:ymp] = { url: ymp_url(File.join(@pkg.project.name, repo.name, "#{@pkg.name}.ymp")) } if binary && dist.vendor == 'openSUSE'

        @binary_links[dist_id][:binary] ||= []
        binary_map[repo.name].each do |b|
          binary_type = b['type']
          # filepath is historic and contains unfortunatly the old repo mapping already.
          # So we have to revert this here...
          filepath = b['filepath']
          # having both gsub! in one line can crash with some ruby builds
          filepath.gsub!(%r{:/}, ':')
          filepath.gsub!(%r{^[^/]*/[^/]*/}, '')

          @binary_links[dist_id][:binary] << { type: binary_type, arch: b['arch'], url: repo.download_url(filepath) }
          if @binary_links[dist_id][:repository].blank?
            repo_filename = binary_type == 'rpm' ? "#{@pkg.project.name}.repo" : ''
            @binary_links[dist_id][:repository] ||= { url: repo.download_url(repo_filename) }
          end
        end
      end
    end
  end

  def image_templates
    @projects = Project.image_templates
    render 'webui/image_templates/index'
  end

  private

  def set_influxdb_data_interconnect
    InfluxDB::Rails.current.tags = {
      interconnect: true
    }
  end

  # removes /private prefix from path
  def unshift_public(path)
    path =~ %r{/public(.*)} ? Regexp.last_match(1) : path
  end

  def check_package_access(project_name, package_name, use_source: true)
    # don't use the cache for use_source
    if use_source
      begin
        Package.get_by_project_and_name(project_name, package_name)
      rescue Authenticator::AnonymousUser
        # TODO: Use pundit for authorization instead
        raise Package::ReadSourceAccessError, "#{project_name} / #{package_name} "
      end
      return
    end

    # generic access checks
    key = "public_package:#{project_name}:#{package_name}"
    allowed = Rails.cache.fetch(key, expires_in: 30.minutes) do
      Package.get_by_project_and_name(project_name, package_name, use_source: false)
      true
    rescue StandardError
      false
    end
    raise Package::UnknownObjectError, "#{project_name} / #{package_name} " unless allowed
  end
end
