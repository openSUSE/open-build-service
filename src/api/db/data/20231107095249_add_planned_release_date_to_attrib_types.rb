# frozen_string_literal: true

class AddPlannedReleaseDateToAttribTypes < ActiveRecord::Migration[7.0]
  def up
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.create_with(
      description: 'A timestamp for the planned release date of an incident.',
      value_count: 1
    ).find_or_create_by(name: 'PlannedReleaseDate')

    maintainer_role = Role.find_by(title: 'maintainer')
    at.attrib_type_modifiable_bies.find_or_create_by(role_id: maintainer_role.id)
  end

  def down
    ans = AttribNamespace.find_by(name: 'OBS')
    ans.attrib_types.find_by(name: 'PlannedReleaseDate').destroy
  end
end
