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
  def self.set_value(key, value)
    backend_value = BackendInfo.find_or_initialize_by(key: key)
    backend_value.value = value
    backend_value.save!
  end

  def self.lastnotification_nr=(nr)
    set_value('lastnotification_nr', nr.to_s)
  end

  def self.get_value(key)
    BackendInfo.where(key: key).pluck(:value)
  end

  def self.get_integer(key)
    nr = get_value(key)
    nr.empty? ? 0 : nr[0].to_i
  end

  def self.lastnotification_nr
    get_integer('lastnotification_nr')
  end

  #### To define class methods as private use private_class_method
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
