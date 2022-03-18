class AddAttributeToEnforceRequestAccepterAndCreatorToBeADifferentPerson < ActiveRecord::Migration[6.1]
  def up
    ans = AttribNamespace.first_or_create(name: 'OBS')
    ans.attrib_types.where(name: 'CreatorCannotAcceptOwnRequests').first_or_create(value_count: 0)
  end

  def down
    ans = AttribNamespace.first_or_create(name: 'OBS')
    ans.attrib_types.where(name: 'CreatorCannotAcceptOwnRequests').delete
  end
end
