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
    login = User.current.login
    path = attribute_url + "?meta=1&user=#{CGI.escape(login)}"
    path += "&comment=#{CGI.escape(comment)}" if comment
    begin
      Suse::Backend.put_source(path, render_attribute_axml)
    rescue ActiveXML::Transport::Error => e
      raise AttributeSaveError.new e.summary
    end
  end

  def store_attribute_axml(attrib, binary = nil)
    values = []
    attrib.each('value') do |val|
      values << val.text
    end

    issues = []
    attrib.each('issue') do |i|
      issues << Issue.find_or_create_by_name_and_tracker(i.value('name'), i.value('tracker'))
    end

    store_attribute(attrib.value('namespace'), attrib.value('name'), values, issues, binary)
  end

  def store_attribute(namespace, name, values, issues, binary = nil)
    # get attrib_type
    attrib_type = AttribType.find_by_namespace_and_name!(namespace, name)

    # update or create attribute entry
    changed = false
    begin
      a = find_attribute(namespace, name, binary)
    rescue AttributeFindError => e
      raise AttributeSaveError, e
    end
    if a.nil?
      # create the new attribute
      a = Attrib.new(attrib_type: attrib_type, binary: binary)
      a.project = self if is_a? Project
      a.package = self if is_a? Package
      if a.attrib_type.value_count
        a.attrib_type.value_count.times do |i|
          a.values.build(position: i, value: "")
        end
      end
      if a.save
        changed = true
      else
        raise AttributeSaveError, a.errors.full_messages.join(", ")
      end
    end
    # write values
    a.update_with_associations(values, issues) || changed
  end

  def find_attribute(namespace, name, binary = nil)
    logger.debug "find_attribute for #{namespace}:#{name}"
    if namespace.nil?
      raise AttributeFindError, "Namespace must be given"
    end
    if name.nil?
      raise AttributeFindError, "Name must be given"
    end
    if binary
      if is_a? Project
        raise AttributeFindError, "binary packages are not allowed in project attributes"
      end
      # rubocop:disable Metrics/LineLength
      a = attribs.joins(attrib_type: :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ? AND attribs.binary = ?", name, namespace, binary).first
    else
      a = attribs.nobinary.joins(attrib_type: :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ?", name, namespace).first
      # rubocop:enable Metrics/LineLength
    end
    if a && a.readonly? # FIXME: joins make things read only
      a = attribs.find a.id
    end
    a
  end

  def render_attribute_axml(params = {})
    builder = Nokogiri::XML::Builder.new

    builder.attributes do |xml|
      render_main_attributes(xml, params)

      # show project values as fallback ?
      if params[:with_project]
        project.render_main_attributes(xml, params)
      end
    end
    builder.doc.to_xml indent: 2, encoding: 'UTF-8',
                              save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                  Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def render_main_attributes(builder, params)
    done={}
    attribs.each do |attr|
      type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
      next if params[:name] && !(attr.attrib_type.name == params[:name])
      next if params[:namespace] && !(attr.attrib_type.attrib_namespace.name == params[:namespace])
      next if params[:binary] && attr.binary != params[:binary]
      next if params[:binary] == "" && attr.binary != "" # switch between all and NULL binary
      done[type_name] = 1 unless attr.binary
      p={}
      p[:name] = attr.attrib_type.name
      p[:namespace] = attr.attrib_type.attrib_namespace.name
      p[:binary] = attr.binary if attr.binary
      builder.attribute(p) do
        unless attr.issues.blank?
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
