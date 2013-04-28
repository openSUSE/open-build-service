
include SearchHelper

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

  def search(what, render_all)
    if render_all and params[:match].blank?
      render_error :status => 400, :errorcode => "empty_match",
                   :message => "No predicate fround in match argument"
      return
    end

    predicate = predicate_from_match_parameter(params[:match])

    logger.debug "searching in #{what}s, predicate: '#{predicate}'"

    xe = XpathEngine.new

    output = ActiveXML::Node.new '<collection/>'
    matches = 0

    xe.find("/#{what}[#{predicate}]", params.slice(:sort_by, :order, :limit, :offset).merge({"render_all" => render_all})) do |item|
      matches = matches + 1
      if item.kind_of? Package or item.kind_of? Project
        # already checked in this case
      elsif item.kind_of? Repository
        # This returns nil if access is not allowed
        next if ProjectUserRoleRelationship.forbidden_project_ids.include? item.db_project_id
      elsif item.kind_of? User
        # Person data is public
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
