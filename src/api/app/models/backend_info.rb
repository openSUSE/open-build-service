# frozen_string_literal: true

# just key:value for things to be stored about the running backend and that are not configuration
class BackendInfo < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  def self.lastnotification_nr=(value)
    backend_value = BackendInfo.find_or_initialize_by(key: 'lastnotification_nr')
    backend_value.value = value
    backend_value.save!
  end

  def self.lastnotification_nr
    BackendInfo.where(key: 'lastnotification_nr').pluck(:value).first.to_i
  end
  #### private
  #### Instance methods (public and then protected/private)
  #### Alias of methods
end

# == Schema Information
#
# Table name: backend_infos
#
#  id         :integer          not null, primary key
#  key        :string(255)      not null
#  value      :string(255)      not null
#  created_at :datetime
#  updated_at :datetime
#
