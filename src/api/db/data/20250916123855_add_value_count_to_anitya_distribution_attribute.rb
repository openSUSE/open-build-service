# frozen_string_literal: true

class AddValueCountToAnityaDistributionAttribute < ActiveRecord::Migration[7.2]
  def up
    ans = AttribNamespace.find_by_name('OBS')
    at = AttribType.find_by(attrib_namespace: ans, name: 'AnityaDistribution')
    at.update!(value_count: 1)
  end

  def down
    ans = AttribNamespace.find_by_name('OBS')
    at = AttribType.find_by(attrib_namespace: ans, name: 'AnityaDistribution')
    at.update!(value_count: nil)
  end
end
