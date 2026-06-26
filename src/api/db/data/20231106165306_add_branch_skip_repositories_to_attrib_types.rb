# frozen_string_literal: true

class AddBranchSkipRepositoriesToAttribTypes < ActiveRecord::Migration[7.0]
  def up
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.create_with(
      description: 'Skip the listed repositories when branching from this project.'
    ).find_or_create_by(name: 'BranchSkipRepositories')

    maintainer_role = Role.find_by(title: 'maintainer')
    at.attrib_type_modifiable_bies.find_or_create_by(role_id: maintainer_role.id)
  end

  def down
    ans = AttribNamespace.find_by(name: 'OBS')
    ans.attrib_types.find_by(name: 'BranchSkipRepositories').destroy
  end
end
