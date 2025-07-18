# frozen_string_literal: true

class AddRoleToLimitReleaseSourceProject < ActiveRecord::Migration[7.2]
  def up
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.find_by(name: 'LimitReleaseSourceProject')
    maintainer_role = Role.find_by(title: 'maintainer')

    at.attrib_type_modifiable_bies.find_or_create_by(role_id: maintainer_role.id)
  end

  def down
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.find_by(name: 'LimitReleaseSourceProject')
    maintainer_role = Role.find_by(title: 'maintainer')

    at.attrib_type_modifiable_bies.find_by(role_id: maintainer_role.id).destroy
  end
end
