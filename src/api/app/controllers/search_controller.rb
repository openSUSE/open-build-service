
class SearchController < ApplicationController

  require 'xpath_engine'

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

  def owner
    params[:attribute] ||= "OBS:OwnerRootProject"

    Suse::Backend.start_test_backend if Rails.env.test?

    unless params[:binary]
      render_error :status => 400, :errorcode => "no_binary",
                   :message => "The search needs at least a 'binary' parameter"
      return
    end

    at = AttribType.find_by_name(params[:attribute])
    unless at
      render_error :status => 404, :errorcode => "unknown_attribute_type",
                   :message => "Attribute Type #{params[:attribute]} does not exist"
      return
    end

    projects = []
    if params[:project]
      # default project specified
      projects = [Project.get_by_name(params[:project])]
    else
      # Find all marked projects
      projects = Project.find_by_attribute_type(at)
      unless projects.length > 0
        render_error :status => 400, :errorcode => "attribute_not_set",
                     :message => "The attribute type #{params[:attribute]} is not set on any projects. No default projects defined."
        return
      end
    end

    # search in each marked project
    @assignees = []
    projects.each do |project|

      attrib = project.attribs.where(attrib_type_id: at.id).first
      limit  = params[:limit] || 1
      filter = ["maintainer","bugowner"]
      devel  = true
      if params[:filter]
        filter=params[:filter].split(",")
      else
        if attrib and v=attrib.values.where(value: "BugownerOnly").first
          filter=["bugowner"]
        end
      end
      if params[:devel]
        devel=false if [ "0", "false" ].include? params[:devel]
      else
        if attrib and v=attrib.values.where(value: "DisableDevel").first
          devel=false
        end
      end

      @assignees = project.find_assignees(params[:binary], limit.to_i, devel, filter)

    end

  end

  private

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

  def search(what, render_all)
    predicate = predicate_from_match_parameter(params[:match])
    
    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    xe = XpathEngine.new

    output = ActiveXML::Node.new '<collection/>'
    matches = 0

    begin
      xe.find("/#{what}[#{predicate}]", params.slice(:sort_by, :order, :limit, :offset).merge({"render_all" => render_all})) do |item|
        matches = matches + 1
        if item.kind_of? Package or item.kind_of? Project
          # already checked in this case
        elsif item.kind_of? Repository
          # This returns nil if access is not allowed
          next if ProjectUserRoleRelationship.forbidden_project_ids.include? item.db_project_id
        elsif item.kind_of? Issue
          # all our hosted issues are public atm
        elsif item.kind_of? BsRequest
          # requests leak (FIXME)
        else
          render_error :status => 400, :message => "unknown object received from collection %s (#{item.inspect})" % predicate
          return
        end
        
        output.add_node(render_all ? item.to_axml : item.to_axml_id)
      end
    rescue XpathEngine::IllegalXpathError => e
      render_error :status => 400, :message => "illegal xpath %s (#{e.message})" % predicate
      return
    end

    output.set_attribute("matches", matches.to_s)
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
      attribs = Attrib.where("attrib_type_id = ? AND db_package_id in (?)", attrib.id, packages.collect { |p| p.id }).all
    else
      attribs = attrib.attribs
    end
    values = AttribValue.where("attrib_id IN (?)", attribs.collect { |a| a.id } ).all
    attribValues = Hash.new
    values.each do |v|
      attribValues[v.attrib_id] ||= Array.new
      attribValues[v.attrib_id] << v
    end
    packages = Package.where("packages.id IN (?)", attribs.collect { |a| a.db_package_id }).includes(:project).all
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
