# frozen_string_literal: true

class AddPackageTemplatesToAttribTypes < ActiveRecord::Migration[7.0]
  def up
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.create_with(
      description: 'Mark this project as a source for package templates'
    ).find_or_create_by(name: 'PackageTemplates')

    admin_role = Role.find_by(title: 'Admin')
    at.attrib_type_modifiable_bies.find_or_create_by(role_id: admin_role.id)
  end

  def down
    ans = AttribNamespace.find_by(name: 'OBS')
    ans.attrib_types.find_by(name: 'PackageTemplates').destroy
  end
end
