
require_relative '../attribute_descriptions'

class SetAttribTypeDescriptions < ActiveRecord::Migration
  def self.up
    update_all_attrib_type_descriptions
  end
end
