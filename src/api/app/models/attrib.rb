class Attrib < ActiveRecord::Base
  belongs_to :db_package
  belongs_to :attrib_type
  has_many :values, :class_name => 'AttribValue', :order => :position, :dependent => :destroy

  def self.inheritance_column
    "bla"
  end

  def cachekey
    "#{attrib_type.name}|#{subpackage}"
  end

  def update_from_xml(node)
    update_values = false

    update_values = true unless node.each_value.length == self.values.count

    node.each_value.each_with_index do |val, i|
      next if val.to_s == self.values[i].value
      update_values = true
      break
    end unless update_values

    if update_values
      logger.debug "--- updating values ---"
      self.values.delete_all
      node.each_value do |val|
        self.values << AttribValue.new(:value => val.to_s)
      end
    end

    self.save
  end

end
