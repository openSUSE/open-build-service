require_relative '../attribute_descriptions'

class RequestDelegateAttribute < ActiveRecord::Migration[6.0]
  def self.up
    ans = AttribNamespace.find_by_name('OBS')

    AttribTypeModifiableBy.reset_column_information

    at = AttribType.find_or_create_by(attrib_namespace: ans, name: 'DelegateRequestTarget')

    role = Role.find_by_title('maintainer')
    AttribTypeModifiableBy.find_or_create_by(role_id: role.id, attrib_type_id: at.id)

    update_all_attrib_type_descriptions
  end

  def self.down
    AttribType.find_by_namespace_and_name('OBS', 'DelegateRequestTarget').delete
  end
end
