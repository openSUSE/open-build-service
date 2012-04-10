# Attribute container inside package meta data
# Attribute definitions are inside attrib_type

class Attrib < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :db_project
  belongs_to :attrib_type
  has_many :values, :class_name => 'AttribValue', :order => :position, :dependent => :destroy

  attr_accessible :attrib_type, :binary, :db_project 

  def cachekey
    if binary
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}|#{binary}"
    else
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    end
  end

  def update_from_xml(node)
    update_values = false

    update_values = true unless node.each_value.length == self.values.count

    node.each_value.each_with_index do |val, i|
      next if val.text == self.values[i].value
      update_values = true
      break
    end unless update_values

    if update_values
      logger.debug "--- updating values ---"
      self.values.delete_all
      position = 1
      node.each_value do |val|
        self.values << AttribValue.new(:value => val.text, :position => position)
        position += 1
      end
    end

    self.save
  end

end
