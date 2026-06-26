# frozen_string_literal: true

class MigrateAnityaDistributionAttributesToProjectsTable < ActiveRecord::Migration[7.2]
  def up
    attribute_type_anitya_distribution = AttribType.find_by_namespace_and_name('OBS', 'AnityaDistribution')
    attribs = attribute_type_anitya_distribution.attribs
    return if attribs.blank?

    attribs.each do |attrib|
      project = attrib.project
      anitya_distribution_name = attrib.values.last&.value
      next if anitya_distribution_name.blank?

      project.update!(anitya_distribution_name: anitya_distribution_name)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
