
include SearchHelper

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

  def attribute
    unless params[:namespace] and params[:name]
      render_error :status => 400, :message => "need namespace and name parameter"
      return
    end
    find_attribute(params[:namespace], params[:name])
  end

  def missing_owner
    params[:limit] ||= "0" #unlimited by default

    @owners = search_owner(params, nil)

  end

  def owner

    Suse::Backend.start_test_backend if Rails.env.test?

    obj = nil
    obj = params[:binary] unless params[:binary].blank?
    obj = User.find_by_login!(params[:user]) unless params[:user].blank?
    obj = Group.find_by_title!(params[:group]) unless params[:group].blank?

    if obj.blank?
      render_error :status => 400, :errorcode => "no_binary",
                   :message => "The search needs at least a 'binary' or 'user' parameter"
      return
    end

    @owners = search_owner(params, obj)
  end

  def predicate_from_match_parameter(p)
    if p=~ /^\(\[(.*)\]\)$/
      pred = $1
    elsif p=~ /^\[(.*)\]$/
      pred = $1
    else
      pred = p
    end
    pred = "*" if pred.nil? or pred.empty?
    return pred
  end

  def filter_items(items, offset, limit)
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
          break if @limit == 0
        end
      end
    end
    nitems
  end

  def search(what, render_all)
    if render_all and params[:match].blank?
      render_error :status => 400, :errorcode => "empty_match",
                   :message => "No predicate fround in match argument"
      return
    end

    predicate = predicate_from_match_parameter(params[:match])

    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    xe = XpathEngine.new

    items = xe.find("/#{what}[#{predicate}]")

    matches = items.size

    if params[:offset] || params[:limit]
      # Add some pagination. Limiting the ids we have
      items = filter_items(items, params[:offset], params[:limit])
    end

    includes = nil

    output = ActiveXML::Node.new '<collection/>'
    output.set_attribute("matches", matches.to_s)

    xml = Hash.new

    # ignore everything that is already in the memcache
    id2cache_key = Hash.new
    if render_all
      items.each { |i| id2cache_key[i] = "xml_#{what}_%d" % i }
    else
      items.each { |i| id2cache_key[i] = "xml_id_#{what}_%d" % i }
    end
    cached = Rails.cache.read_multi(*(id2cache_key.values))
    search_items = Array.new
    items.each do |i|
      key = id2cache_key[i]
      if cached.has_key? key
        xml[i] = cached[key]
      else
        search_items << i
      end
    end

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
      includes = [:bs_request_actions, :bs_request_histories, :reviews]
    when :person
      relation = User.where(id: search_items)
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
      xml[item.id] = render_all ? item.to_axml : item.to_axml_id
    end if items.size > 0

    items.each do |i|
      output.add_node(xml[i])
    end

    render :text => output.dump_xml, :content_type => "text/xml"
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
    attrib = AttribType.find_by_namespace_and_name(namespace, name)
    unless attrib
      render_error :status => 404, :message => "no such attribute"
      return
    end
    project = Project.get_by_name(params[:project]) if params[:project]
    if params[:package]
      if params[:project]
         packages = Package.get_by_project_and_name(params[:project], params[:package])
      else
         packages = Package.where(name: params[:package]).all
      end
    elsif project
      packages = project.packages
    end

    if packages
      attribs = Attrib.where("attrib_type_id = ? AND db_package_id in (?)", attrib.id, packages.collect { |p| p.id })
    else
      attribs = attrib.attribs
    end
    values = AttribValue.where("attrib_id IN (?)", attribs.collect { |a| a.id } )
    attribValues = Hash.new
    values.each do |v|
      attribValues[v.attrib_id] ||= Array.new
      attribValues[v.attrib_id] << v
    end
    packages = Package.where("packages.id IN (?)", attribs.collect { |a| a.db_package_id }).includes(:project)
    pack2attrib = Hash.new
    attribs.each do |a|
      if a.db_package_id
        pack2attrib[a.db_package_id] = a.id
      end
    end
    packages.sort! { |x,y| x.name <=> y.name }
    projects = packages.collect { |p| p.project }.uniq
    builder = Builder::XmlMarkup.new( :indent => 2 )
    xml = builder.attribute(:namespace => namespace, :name => name) do
      projects.each do |proj|
        builder.project(:name => proj.name) do
          packages.each do |p|
             next if p.db_project_id != proj.id
             builder.package(:name => p.name) do
               values = attribValues[pack2attrib[p.id]]
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
    render :text => xml, :content_type => "text/xml"
  end

end
