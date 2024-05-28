# a model that has attributes - e.g. a project and a package
module HasAttributes
  extend ActiveSupport::Concern

  class AttributeSaveError < APIError
  end

  def write_attributes
    return unless CONFIG['global_write_through']

    project_name = is_a?(Project) ? name : project.name
    if is_a?(Package)
      Backend::Api::Sources::Package.write_attributes(project_name, name, User.session!.login, render_attribute_axml)
    else
      Backend::Api::Sources::Project.write_attributes(project_name, User.session!.login, render_attribute_axml)
    end
  rescue Backend::Error => e
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
    a = find_attribute(namespace, name, binary)
    unless a
      # create the new attribute
      a = Attrib.create(attrib_type: attrib_type, binary: binary)
      a.project = self if is_a?(Project)
      a.package = self if is_a?(Package)
    end
    # write values
    a.update_with_associations(values, issues)
    return unless a.saved_changes?

    write_attributes
  end

  def find_attribute(namespace, name, binary = nil)
    raise AttributeFindError, 'Namespace must be given' unless namespace
    raise AttributeFindError, 'Name must be given' unless name
    raise AttributeFindError, 'binary packages are not allowed in project attributes' if is_a?(Project) && binary

    query = attribs.joins(attrib_type: :attrib_namespace)
    query = query.where(attrib_types: { name: name },
                        binary: binary,
                        attrib_namespaces: { name: namespace })
    query.readonly(false).first
  end

  def render_attribute_axml(opts = {})
    builder = Nokogiri::XML::Builder.new

    builder.attributes do |xml|
      render_main_attributes(xml, opts)

      next unless is_a?(Package) && opts[:with_project]

      project.render_main_attributes(xml, opts)
    end
    builder.doc.to_xml(indent: 2, encoding: 'UTF-8',
                       save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                         Nokogiri::XML::Node::SaveOptions::FORMAT)
  end

  def render_main_attributes(builder, opts)
    attribs.each do |attr|
      next unless render?(attr, opts[:attrib_type], opts[:binary])

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
        render_single_attribute(attr, opts[:with_default], builder)
      end
    end
  end

  private

  def matches_binary_filter?(filter, binary)
    return true unless filter
    return false if binary != filter

    # switch between all and NULL binary
    filter != '' || binary == ''
  end

  def render?(attr, filter_attrib_type, filter_binary)
    return false if filter_attrib_type && !(attr.attrib_type == filter_attrib_type)

    matches_binary_filter?(filter_binary, attr.binary)
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
