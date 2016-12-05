class SearchController < ApplicationController
  require_dependency 'xpath_engine'

  def project
    search(:project, true)
  end

  def project_id
    search(:project, false)
  end

  def package
    search(:package, true)
  end

  def package_id
    search(:package, false)
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

  def attribute
    unless params[:namespace] && params[:name]
      render_error status: 400, message: "need namespace and name parameter"
      return
    end
    find_attribute(params[:namespace], params[:name])
  end

  def missing_owner
    params[:limit] ||= "0" # unlimited by default

    @owners = Owner.search(params, nil).map(&:to_hash)
  end

  def owner
    Suse::Backend.start_test_backend if Rails.env.test?

    obj = nil
    obj = params[:binary] unless params[:binary].blank?
    obj = User.find_by_login!(params[:user]) unless params[:user].blank?
    obj = Group.find_by_title!(params[:group]) unless params[:group].blank?
    obj = Package.get_by_project_and_name(params[:project], params[:package]) unless params[:project].blank? || params[:package].blank?
    obj = Project.get_by_name(params[:project]) if obj.nil? && params[:project].present?

    if obj.blank?
      render_error status: 400, errorcode: "no_binary",
                   message: "The search needs at least a 'binary' or 'user' parameter"
      return
    end

    @owners = Owner.search(params, obj).map(&:to_hash)
  end

  def predicate_from_match_parameter(p)
    pred = case p
      when /^\(\[(.*)\]\)$/
           $1
      when /^\[(.*)\]$/
           $1
      else
           p
    end
    pred = "*" if pred.nil? || pred.empty?
    pred
  end

  def filter_items(items)
    begin
      @offset = Integer(params[:offset])
    rescue
      @offset = 0
    end
    begin
      @limit = Integer(params[:limit])
    rescue
      @limit = items.size
    end
    nitems = Array.new
    items.each do |item|
      if @offset > 0
        @offset -= 1
      else
        nitems << item
        if @limit
          @limit -= 1
          break if @limit.zero?
        end
      end
    end
    nitems
  end

  # unfortunately read_multi hangs with just too many items
  # so maximize the keys to query
  def read_multi_workaround(keys)
    ret = Hash.new
    while !keys.empty?
      slice = keys.slice!(0, 300)
      ret.merge!(Rails.cache.read_multi(*slice))
    end
    ret
  end

  def filter_items_from_cache(items, xml, key_template)
    # ignore everything that is already in the memcache
    id2cache_key = Hash.new
    items.each { |i| id2cache_key[i] = key_template % i }
    cached = read_multi_workaround(id2cache_key.values)
    search_items = Array.new
    items.each do |i|
      key = id2cache_key[i]
      if cached.has_key? key
        xml[i] = cached[key]
      else
        search_items << i
      end
    end
    search_items
  end

  def search(what, render_all)
    if render_all && params[:match].blank?
      render_error status: 400, errorcode: "empty_match",
                   message: "No predicate found in match argument"
      return
    end

    predicate = predicate_from_match_parameter(params[:match])

    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    xe = XpathEngine.new

    items = xe.find("/#{what}[#{predicate}]")

    matches = items.size

    if params[:offset] || params[:limit]
      # Add some pagination. Limiting the ids we have
      items = filter_items(items)
    end

    includes = nil
    opts = {}

    output = "<collection matches=\"#{matches}\">\n"

    xml = Hash.new # filled by filter
    if render_all
      key_template = "xml_#{what}_%d"
    else
      key_template = "xml_id_#{what}_%d"
    end
    search_items = filter_items_from_cache(items, xml, key_template)

    case what
    when :package
      relation = Package.where(id: search_items)
      includes = [:project]
    when :project
      relation = Project.where(id: search_items)
      if render_all
        includes = [:repositories]
      else
        includes = []
        relation = relation.select("projects.id,projects.name")
      end
    when :repository
      relation = Repository.where(id: search_items)
      includes = [:project]
    when :request
      relation = BsRequest.where(id: search_items)
      includes = [:bs_request_actions, :reviews]
      opts[:withhistory] = 1 if params[:withhistory]
      opts[:withfullhistory] = 1 if params[:withfullhistory]
    when :person
      relation = User.where(id: search_items)
      includes = []
    when :channel
      relation = ChannelBinary.where(id: search_items)
      includes = []
    when :channel_binary
      relation = ChannelBinary.where(id: search_items)
      includes = []
    when :released_binary
      relation = BinaryRelease.where(id: search_items)
      includes = []
    when :issue
      relation = Issue.where(id: search_items)
      includes = [:issue_tracker]
    else
      logger.fatal "strange model: #{what}"
    end
    relation = relation.includes(includes).references(includes)

    # TODO support sort_by and order parameters?

    relation.each do |item|
      next if xml[item.id]
      xml[item.id] = render_all ? item.to_axml(opts) : item.to_axml_id
      xml[item.id].gsub!(/(..*)/, "  \\1") # indent it by two spaces, if line is not empty
    end if items.size > 0

    items.each do |i|
      output << xml[i]
    end

    output << "</collection>"
    render text: output, content_type: "text/xml"
  end

  # specification of this function:
  # supported paramters:
  # namespace: attribute namespace (required string)
  # name: attribute name  (required string)
  # project: limit search to project name (optional string)
  # package: limit search to package name (optional string)
  # ignorevalues: do not output attribute values (optional boolean)
  # withproject: output project defaults if no value set for package (optional boolean)
  #              such values also map against value paramter if given
  # value: limit search to attributes with value (optional string)
  # value_substr: limit search to attributes that match value substring (optional string)
  #
  # output: XML <attribute namespace name><project name>values? packages?</project></attribute>
  #         with packages = <package name>values?</package>
  #          and values   = <values>value+</values>
  #          and value    = <value>CDATA</value>
  def find_attribute(namespace, name)
    attrib = AttribType.find_by_namespace_and_name!(namespace, name)

    # gather the relation for attributes depending on project/package combination
    if params[:package]
      if params[:project]
        attribs = Package.get_by_project_and_name(params[:project], params[:package]).attribs
      else
        attribs = attrib.attribs.where(package_id: Package.where(name: params[:package]))
      end
    else
      if params[:project]
        attribs = attrib.attribs.where(package_id: Project.get_by_name(params[:project]).packages)
      else
        attribs = attrib.attribs
      end
    end

    # get the values associated with the attributes and store them
    attribs = attribs.pluck(:id, :package_id)
    values = AttribValue.where("attrib_id IN (?)", attribs.collect { |a| a[0] })
    attribValues = Hash.new
    values.each do |v|
      attribValues[v.attrib_id] ||= Array.new
      attribValues[v.attrib_id] << v
    end
    # retrieve the package name and project for the attributes
    packages = Package.where("packages.id IN (?)", attribs.collect { |a| a[1] }).pluck(:id, :name, :project_id)
    pack2attrib = Hash.new
    attribs.each do |attrib_id, pkg|
      pack2attrib[pkg] = attrib_id
    end
    packages.sort! { |x, y| x[0] <=> y[0] }
    projects = Project.where(id: packages.collect { |p| p[2] }).distinct.pluck(:id, :name)
    builder = Builder::XmlMarkup.new(indent: 2)
    xml = builder.attribute(namespace: namespace, name: name) do
      projects.each do |prj_id, prj_name|
        builder.project(name: prj_name) do
          packages.each do |pkg_id, pkg_name, pkg_prj|
            next if pkg_prj != prj_id
            builder.package(name: pkg_name) do
              values = attribValues[pack2attrib[pkg_id]]
              unless values.nil?
                builder.values do
                  values.each { |v| builder.value(v.value) }
                end
              end
            end
          end
        end
      end
    end
    render text: xml, content_type: "text/xml"
  end
end
