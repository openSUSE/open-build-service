
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

  def attribute
    unless params[:namespace] and params[:name]
      render_error :status => 400, :message => "need namespace and name parameter"
      return
    end
    find_attribute(params[:namespace], params[:name])
  end

  private

  def predicate_from_match_parameter(p)
    if p=~ /\[(.*)\]/
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

    output = String.new
    output << "<?xml version='1.0' encoding='UTF-8'?>\n"
    output << "<collection>\n"

    begin
      xe.find("/#{what}[#{predicate}]", params.slice(:sort_by, :order, :limit, :offset).merge({"render_all" => render_all})) do |item|
        if item.kind_of? DbPackage or item.kind_of? DbProject
          # already checked in this case
        elsif item.kind_of? Repository
          # This returns nil if access is not allowed
          next unless DbProject.find item.db_project_id
        elsif item.kind_of? Issue
          # all our hosted issues are public atm
        else
          render_error :status => 400, :message => "unknown object received from collection %s (#{item.inspect})" % predicate
          return
        end
        
        str = (render_all ? item.to_axml : item.to_axml_id)
        output << str.split(/\n/).map {|l| l.match(/\s*\</) ? "  "+l : l}.join("\n") + "\n"
      end
    rescue XpathEngine::IllegalXpathError => e
      render_error :status => 400, :message => "illegal xpath %s (#{e.message})" % predicate
      return
    end

    output << "</collection>\n"
    render :text => output, :content_type => "text/xml"
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
    project = DbProject.get_by_name(params[:project]) if params[:project]
    if params[:package]
      if params[:project]
         packages = DbPackage.get_by_project_and_name(params[:project], params[:package])
      else
         packages = DbPackage.where("name = BINARY ?", params[:package]).all
      end
    elsif project
      packages = project.db_packages
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
    packages = DbPackage.where("db_packages.id IN (?)", attribs.collect { |a| a.db_package_id }).includes(:db_project).all
    pack2attrib = Hash.new
    attribs.each do |a|
      if a.db_package_id
        pack2attrib[a.db_package_id] = a.id
      end
    end
    packages.sort! { |x,y| x.name <=> y.name }
    projects = packages.collect { |p| p.db_project }.uniq
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
