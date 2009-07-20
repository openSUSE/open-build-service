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

    #TODO: store defaults and allowed values
    self.save
  end
end
