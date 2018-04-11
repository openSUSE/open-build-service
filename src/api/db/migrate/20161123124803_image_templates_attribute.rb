# frozen_string_literal: true

class ImageTemplatesAttribute < ActiveRecord::Migration[5.0]
  class AttribTypeModifiableBy < ApplicationRecord; end

  def self.up
    ans = AttribNamespace.find_by_name 'OBS'
    role = Role.find_by_title('Admin')

    AttribTypeModifiableBy.reset_column_information

    at = AttribType.create(attrib_namespace: ans, name: 'ImageTemplates')
    AttribTypeModifiableBy.create(role_id: role.id, attrib_type_id: at.id)
  end

  def self.down
    AttribType.find_by_namespace_and_name('OBS', 'ImageTemplates').delete
  end
end
