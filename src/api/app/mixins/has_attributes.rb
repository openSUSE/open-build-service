# a model that has attributes - e.g. a project and a package
module HasAttributes
  def self.included(base)
    base.class_eval do
      has_many :ratings, as: :db_object, dependent: :delete_all
    end
  end

  class AttributeSaveError < APIException
  end

  def write_attributes(comment = nil)
    project_name = is_a?(Project) ? name : project.name
    if is_a?(Package)
      Backend::Api::Sources::Package.write_attributes(project_name, name, User.current.login, render_attribute_axml, comment)
    else
      Backend::Api::Sources::Project.write_attributes(project_name, User.current.login, render_attribute_axml, comment)
    end
  rescue ActiveXML::Transport::Error => e
    raise AttributeSaveError, e.summary
  end

  def store_attribute_xml(attrib, binary = nil)
    values = []
    attrib.elements('value') do |val|
      values << val
    end

    issues = []
    attrib.elements('issue') do |i|
      issues << Issue.find_or_create_by_name_and_tracker(i['name'], i['tracker'])
    end

    store_attribute(attrib['namespace'], attrib['name'], values, issues, binary)
  end

  def store_attribute(namespace, name, values, issues, binary = nil)
    # get attrib_type
    attrib_type = AttribType.find_by_namespace_and_name!(namespace, name)

    # update or create attribute entry
    changed = false
    a = find_attribute(namespace, name, binary)
    if a.nil?
      # create the new attribute
      a = Attrib.new(attrib_type: attrib_type, binary: binary)
      a.project = self if is_a? Project
      a.package = self if is_a? Package
      (a.attrib_type.value_count || 0).times do |i|
        a.values.build(position: i, value: values[i])
      end
      raise AttributeSaveError, a.errors.full_messages.join(', ') unless a.save
      changed = true
    end
    # write values
    a.update_with_associations(values, issues) || changed
  end

  def find_attribute(namespace, name, binary = nil)
    raise AttributeFindError, 'Namespace must be given' unless namespace
    raise AttributeFindError, 'Name must be given' unless name
    if is_a?(Project) && binary
      raise AttributeFindError, 'binary packages are not allowed in project attributes'
    end
    query = attribs.joins(attrib_type: :attrib_namespace)
    query = query.where(attrib_types: { name: name },
                        binary: binary,
                        attrib_namespaces: { name: namespace })
    query.readonly(false).first
  end

  def render_attribute_axml(params = {})
    builder = Nokogiri::XML::Builder.new

    builder.attributes do |xml|
      render_main_attributes(xml, params)

      # show project values as fallback ?
      project.render_main_attributes(xml, params) if params[:with_project]
    end
    builder.doc.to_xml indent: 2, encoding: 'UTF-8',
                              save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                         Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def render_main_attributes(builder, params)
    done = {}
    attribs.each do |attr|
      type_name = attr.attrib_type.attrib_namespace.name + ':' + attr.attrib_type.name
      next if params[:name] && attr.attrib_type.name != params[:name]
      next if params[:namespace] && attr.attrib_type.attrib_namespace.name != params[:namespace]
      next if params[:binary] && attr.binary != params[:binary]
      next if params[:binary] == '' && attr.binary != '' # switch between all and NULL binary
      done[type_name] = 1 unless attr.binary
      p = {}
      p[:name] = attr.attrib_type.name
      p[:namespace] = attr.attrib_type.attrib_namespace.name
      p[:binary] = attr.binary if attr.binary
      builder.attribute(p) do
        if attr.issues.present?
          attr.issues.each do |ai|
            builder.issue(name: ai.name, tracker: ai.issue_tracker.name)
          end
        end
        render_single_attribute(attr, params[:with_default], builder)
      end
    end
  end

  def render_single_attribute(attr, with_default, builder)
    if attr.values.empty?
      if with_default
        attr.attrib_type.default_values.each do |val|
          builder.value(val.value)
        end
      end
    else
      attr.values.each do |val|
        builder.value(val.value)
      end
    end
  end
end
