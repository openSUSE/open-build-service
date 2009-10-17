class AttribType < ActiveRecord::Base
  belongs_to :db_project

  has_many :attribs, :dependent => :destroy
  has_many :default_values, :class_name => 'AttribDefaultValue', :dependent => :delete_all
  has_many :allowed_values, :class_name => 'AttribAllowedValue', :dependent => :delete_all
  belongs_to :attrib_namespace

  def self.inheritance_column
    "bla"
  end

  def type
    read_attribute :type
  end

  def type=(val)
    write_attribute :type, val
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))
    if default_values.length > 0 or allowed_values.length > 0
      node.attribute(:name => self.name, :type => self.type) do |attr|
        if default_values.length > 0
          attr.default do |default|
            default_values.each do |def_val|
              default.value def_val.value
            end
          end
        end

        if allowed_values.length > 0
          attr.allowed do |allowed|
            allowed_values.each do |all_val|
              allowed.value all_val.value
            end
          end
        end
      end
    else
      node.attribute(:name => self.name, :type => self.type)
    end
  end

  def update_from_xml(node)
    self.type = node.type
  
    if node.has_element? :default
      logger.debug "--- updating attrib default definition content ---"

      update_values = false
      update_values = true unless node.default.each_value.length == self.default_values.count

      node.default.each_value.each_with_index do |val, i|
        next if val.to_s == self.default_values[i].value
        update_values = true
        break
      end unless update_values

      if update_values
        logger.debug "--- updating values ---"
        self.default_values.delete_all
        node.default.each_value do |val|
          self.default_values << AttribDefaultValue.new(:value => val.to_s)
        end
      end
    else
      self.default_values.delete_all
    end

    if node.has_element? :allowed
      logger.debug "--- updating attrib allowed definition content ---"
      update_values = false
      update_values = true unless node.allowed.each_value.length == self.allowed_values.count

      node.allowed.each_value.each_with_index do |val, i|
        next if val.to_s == self.allowed_values[i].value
        update_values = true
        break
      end unless update_values

      if update_values
        logger.debug "--- updating values ---"
        self.allowed_values.delete_all
        node.allowed.each_value do |val|
          self.allowed_values << AttribAllowedValue.new(:value => val.to_s)
        end
      end
    else
      self.allowed_values.delete_all
    end

    self.save
  end
end
