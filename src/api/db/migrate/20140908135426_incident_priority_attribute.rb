# frozen_string_literal: true

class IncidentPriorityAttribute < ActiveRecord::Migration[4.2]
  class AttribTypeModifiableBy < ApplicationRecord; end

  def self.up
    role = Role.find_by_title('Admin')
    ans = AttribNamespace.find_by_name 'OBS'

    AttribTypeModifiableBy.reset_column_information

    at = AttribType.create(attrib_namespace: ans, name: 'IncidentPriority', value_count: 1)
    AttribTypeModifiableBy.create(role_id: role.id, attrib_type_id: at.id)
  end

  def self.down
    AttribType.find_by_namespace_and_name('OBS', 'IncidentPriority').delete
  end
end
