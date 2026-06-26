class AddAttributeDefaultValues < ActiveRecord::Migration[5.2]
  def up
    ans = AttribNamespace.where(name: 'OBS').first
    return unless ans

    at = ans.attrib_types.where(name: 'QualityCategory').first
    at.default_values.where(value: 'Development', position: 1).first_or_create if at

    at = ans.attrib_types.where(name: 'MaintenanceIdTemplate').first
    at.default_values.where(value: '%Y-%C', position: 1).first_or_create if at
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
