class SearchController < ApplicationController
  require 'xpath_engine'

  class IllegalXpathError < APIError
    setup 'illegal_xpath_error', 400
  end

  def project
    search(:project, true)
  end

  def project_id
    search(:project, false)
  end

  # DEPRECATED: '/search/project_id' is deprecated in favour of '/search/project/id'
  # Lets use a different controller method for this route in order to track usage
  # through influxdb-rails and to keep them separate for later removal
  def project_id_deprecated
    project_id
  end

  def package
    search(:package, true)
  end

  def package_id
    search(:package, false)
  end

  # DEPRECATED: '/search/package_id' is deprecated in favour of '/search/package/id'
  # Lets use a different controller method for this route in order to track usage
  # through influxdb-rails and to keep them separate for later removal
  def package_id_deprecated
    package_id
  end

  def repository_id
    search(:repository, false)
  end

  def issue
    search(:issue, true)
  end

  def person
    search(:person, true)
  end

  def bs_request
    search(:request, true)
  end

  def bs_request_id
    search(:request, false)
  end

  def channel
    search(:channel, true)
  end

  def channel_binary
    search(:channel_binary, true)
  end

  def channel_binary_id
    search(:channel_binary, false)
  end

  def released_binary
    search(:released_binary, true)
  end

  def released_binary_id
    search(:released_binary, false)
  end

  def missing_owner
    params[:limit] ||= '0' # unlimited by default

    @owners = OwnerSearch::Missing.new(params).find.map(&:to_hash)
  end

  def owner_group_or_user
    if params[:user].present?
      User.find_by_login!(params[:user])
    elsif params[:group].present?
      Group.find_by_title!(params[:group])
    end
  end

  def owner_packages_or_projects
    return if params[:project].blank? && params[:package].blank?

    if params[:package].present?
      if params[:project].blank?
        attribute = AttribType.find_by_name!(params[:attribute] || 'OBS:OwnerRootProject')
        # Find marked projects
        projects = Project.joins(:attribs).where(attribs: { attrib_type_id: attribute.id })
        return projects unless params[:package]

        pkgs = []
        search = OwnerSearch::Container.new(params)
        projects.each do |prj|
          pkg = prj.find_package(params[:package])
          next unless pkg

          pkgs << if search.devel_disabled?(prj)
                    pkg
                  else
                    pkg.resolve_devel_package
                  end
        end
        return pkgs
      end

      [Package.get_by_project_and_name(params[:project], params[:package])]
    else
      [Project.get_by_name(params[:project])]
    end
  end

  def owner
    if params[:binary].present?
      owners = OwnerSearch::Assignee.new(params).for(params[:binary])
    elsif (obj = owner_group_or_user)
      owners = OwnerSearch::Owned.new(params).for(obj)
    end
    if owners.nil? && (objs = owner_packages_or_projects)
      objs.each do |object|
        owners = OwnerSearch::Container.new(params).for(object)
        @owners ||= owners.map(&:to_hash)
      end
      return @owners unless owners.nil?
    end

    if owners.nil?
      render_error status: 400, errorcode: 'no_binary',
                   message: "The search needs at least a 'binary', 'package' or 'user' parameter"
      return
    end

    @owners = owners.map(&:to_hash)
  end

  def predicate_from_match_parameter(p)
    pred = case p
           when /^\(\[(.*)\]\)$/, /^\[(.*)\]$/
             Regexp.last_match(1)
           else
             p
           end
    pred = '*' if pred.blank?
    pred
  end

  # unfortunately read_multi hangs with just too many items
  # so maximize the keys to query
  def read_multi_workaround(keys)
    ret = {}
    until keys.empty?
      slice = keys.slice!(0, 300)
      ret.merge!(Rails.cache.read_multi(*slice))
    end
    ret
  end

  def filter_items_from_cache(items, xml, key_template)
    # ignore everything that is already in the memcache
    id2cache_key = {}
    items.each { |i| id2cache_key[i] = key_template % i }
    cached = read_multi_workaround(id2cache_key.values)
    search_items = []
    items.each do |i|
      key = id2cache_key[i]
      if cached.key?(key)
        xml[i] = cached[key]
      else
        search_items << i
      end
    end
    search_items
  end

  def search(what, render_all)
    if render_all && params[:match].blank?
      render_error status: 400, errorcode: 'empty_match',
                   message: 'No predicate found in match argument'
      return
    end

    predicate = predicate_from_match_parameter(params[:match])

    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    items = find_items(what, predicate)

    matches = items.size
    if render_all && search_results_exceed_configured_limit?(matches)
      render_error status: 403, errorcode: 'search_results_exceed_configured_limit', message: <<~MESSAGE.chomp
        The number of results returned by the performed search exceeds the configured limit.

        You can:
        - retrieve only the ids by using an '/search/.../id' API endpoint, or
        - reduce the number of matches of your search:
          - paginating your results, through the 'limit' and 'offset' parameters, or
          - adjusting your `match` expression.
      MESSAGE

      return
    end

    if params[:offset] || params[:limit]
      # Add some pagination. Limiting the ids we have
      items = filter_items(items)
    end

    opts = {}

    if what == :request
      opts[:withhistory] = 1 if params[:withhistory]
      opts[:withfullhistory] = 1 if params[:withfullhistory]
    end

    output = "<collection matches=\"#{matches}\">\n"

    xml = {} # filled by filter
    key_template = if render_all
                     "xml_#{what}_%d"
                   else
                     "xml_id_#{what}_%d"
                   end
    search_items = filter_items_from_cache(items, xml, key_template)

    search_finder = SearchFinder.new(what: what, search_items: search_items, render_all: render_all)

    relation = search_finder.call

    unless items.empty?
      relation.each do |item|
        next if xml[item.id]

        xml[item.id] = render_all ? item.to_axml(opts) : item.to_axml_id
        xml[item.id].gsub!(/(..*)/, '  \\1') # indent it by two spaces, if line is not empty
      end
    end

    items.each do |i|
      output << xml[i]
    end

    output << '</collection>'
    render xml: output
  end

  private

  def filter_items(items)
    offset = params.fetch(:offset, 0).to_i
    limit = params.fetch(:limit, items.size).to_i
    Kaminari.paginate_array(items, limit: limit, offset: offset)
  end

  def group_attribute_values_by_attrib_id(values)
    attrib_values = {}
    values.each do |v|
      attrib_values[v.attrib_id] ||= []
      attrib_values[v.attrib_id] << v
    end
    attrib_values
  end

  def find_attribs(attrib, project_name, package_name)
    return attrib.attribs if project_name.blank? && package_name.blank?

    return Package.get_by_project_and_name(project_name, package_name).attribs if project_name.present? && package_name.present?

    if package_name
      attrib.attribs.where(package_id: Package.where(name: package_name))
    else # project_name
      attrib.attribs.where(package_id: Project.get_by_name(project_name).packages)
    end
  end

  def find_items(what, predicate)
    XpathEngine.new.find("/#{what}[#{predicate}]")
  rescue XpathEngine::IllegalXpathError => e
    raise IllegalXpathError, "Error found searching elements '#{what}' with xpath predicate: '#{predicate}'.\n\n" \
                             "Detailed error message from parser: #{e.message}"
  end

  def search_results_exceed_configured_limit?(matches)
    config_limit = CONFIG['limit_for_search_results']
    return false if config_limit.blank?

    params_limit = params[:limit].present? && params[:limit] =~ /\A\d+\z/ ? params[:limit].to_i : nil

    returned_results = params_limit.present? && params_limit < matches ? params_limit : matches
    return false if returned_results <= config_limit

    true
  end
end
