class AddLimitReleaseSourceProject < ActiveRecord::Migration[6.1]
  def up
    ans = AttribNamespace.first_or_create(name: 'OBS')
    ans.attrib_types.where(name: 'LimitReleaseSourceProject').first_or_create
  end

  def down
    ans = AttribNamespace.first_or_create(name: 'OBS')
    ans.attrib_types.where(name: 'LimitReleaseSourceProject').delete
  end
end
