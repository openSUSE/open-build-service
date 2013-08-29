# a model that has attributes - e.g. a project and a package
module HasAttributes

  def self.included(base)
    base.class_eval do
      has_many :ratings, :as => :db_object, :dependent => :delete_all
    end
  end

  def write_attributes(comment=nil)
    login = User.current.login
    path = self.attribute_url + "?meta=1&user=#{CGI.escape(login)}"
    path += "&comment=#{CGI.escape(comment)}" if comment
    Suse::Backend.put_source(path, self.render_attribute_axml)
  end

  class SaveError < APIException
    setup "attribute_save_error"
  end

  def store_attribute_axml(attrib, binary=nil)

    atype = check_attrib!(attrib)

    # verify with allowed values for this attribute definition
    unless atype.allowed_values.empty?
      logger.debug("Verify value with allowed")
      attrib.each_value.each do |value|
        found = false
        atype.allowed_values.each do |allowed|
          if allowed.value == value.text
            found = true
            break
          end
        end
        if !found
          raise SaveError, "attribute value #{value} for '#{attrib.namespace}':'#{attrib.name} is not allowed'"
        end
      end
    end
    # update or create attribute entry
    changed = false
    a = find_attribute(attrib.namespace, attrib.name, binary)
    if a.nil?
      # create the new attribute entry
      if binary
        a = self.attribs.create(:attrib_type => atype, :binary => binary)
      else
        a = self.attribs.create(:attrib_type => atype)
      end
      changed = true
    end
    # write values
    changed = true if a.update_from_xml(attrib)
    return changed
  end

  def check_attrib!(attrib)
    raise SaveError, "attribute type without a namespace " if not attrib.namespace
    raise SaveError, "attribute type without a name " if not attrib.name

    # check attribute type
    if (not atype = AttribType.find_by_namespace_and_name(attrib.namespace, attrib.name) or atype.blank?)
      raise SaveError, "unknown attribute type '#{attrib.namespace}':'#{attrib.name}'"
    end
    # verify the number of allowed values
    if atype.value_count and attrib.has_element? :value and atype.value_count != attrib.each_value.length
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' has #{attrib.each_value.length} values, but only #{atype.value_count} are allowed"
    end
    if atype.value_count and atype.value_count > 0 and not attrib.has_element? :value
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' requires #{atype.value_count} values, but none given"
    end
    if attrib.has_element? :issue and not atype.issue_list
      raise SaveError, "attribute '#{attrib.namespace}:#{attrib.name}' has issue elements which are not allowed in this attribute"
    end
    atype
  end

  def find_attribute(namespace, name, binary=nil)
    logger.debug "find_attribute for #{namespace}:#{name}"
    if namespace.nil?
      raise RuntimeError, "Namespace must be given"
    end
    if name.nil?
      raise RuntimeError, "Name must be given"
    end
    if binary
      if self.is_a? Project
        raise RuntimeError, "binary packages are not allowed in project attributes"
      end
      a = attribs.joins(:attrib_type => :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ? AND attribs.binary = ?", name, namespace, binary).first
    else
      a = attribs.nobinary.joins(:attrib_type => :attrib_namespace).where("attrib_types.name = ? and attrib_namespaces.name = ?", name, namespace).first
    end
    if a && a.readonly? # FIXME: joins make things read only
      a = attribs.find a.id
    end
    return a
  end

  def render_attribute_axml(params={})
    builder = Nokogiri::XML::Builder.new

    builder.attributes do |xml|
      render_main_attributes(xml, params)

      # show project values as fallback ?
      if params[:with_project]
        self.project.render_main_attributes(xml, params)
      end
    end
    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                  Nokogiri::XML::Node::SaveOptions::FORMAT
  end

  def render_main_attributes(builder, params)
    done={}
    attribs.each do |attr|
      type_name = attr.attrib_type.attrib_namespace.name+":"+attr.attrib_type.name
      next if params[:name] and not attr.attrib_type.name == params[:name]
      next if params[:namespace] and not attr.attrib_type.attrib_namespace.name == params[:namespace]
      next if params[:binary] and attr.binary != params[:binary]
      next if params[:binary] == "" and attr.binary != "" # switch between all and NULL binary
      done[type_name]=1 if not attr.binary
      p={}
      p[:name] = attr.attrib_type.name
      p[:namespace] = attr.attrib_type.attrib_namespace.name
      p[:binary] = attr.binary if attr.binary
      builder.attribute(p) do
        unless attr.issues.blank?
          attr.issues.each do |ai|
            builder.issue(:name => ai.issue.name, :tracker => ai.issue.issue_tracker.name)
          end
        end
        render_single_attribute(attr, params[:with_default], builder)
      end
    end
  end

  def render_single_attribute(attr, with_default, builder)
    unless attr.values.empty?
      attr.values.each do |val|
        builder.value(val.value)
      end
    else
      if with_default
        attr.attrib_type.default_values.each do |val|
          builder.value(val.value)
        end
      end
    end
  end


end
