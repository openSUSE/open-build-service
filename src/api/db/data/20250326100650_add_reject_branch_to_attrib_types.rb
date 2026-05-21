# frozen_string_literal: true

class AddRejectBranchToAttribTypes < ActiveRecord::Migration[7.0]
  def up
    ans = AttribNamespace.find_by(name: 'OBS')
    at = ans.attrib_types.create_with(
      description: 'Reject Branch Operation',
      value_count: 1
    ).find_or_create_by(name: 'RejectBranch')

    maintainer_role = Role.find_by(title: 'maintainer')
    at.attrib_type_modifiable_bies.find_or_create_by(role_id: maintainer_role.id)
  end

  def down
    ans = AttribNamespace.find_by(name: 'OBS')
    ans.attrib_types.find_by(name: 'RejectBranch').destroy
  end
end
