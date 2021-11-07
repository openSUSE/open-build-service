# TODO: Please overwrite this comment with something explaining the model target
class PackageCheckUpgrade < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_one :packages
  
  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private


  #### Instance methods (public and then protected/private)

  def run_checkupgrade(urlsrc, regexurl, regexver, currentver, separator, debug, user_login)
    result = Backend::Api::Sources::PackageCheckUpgrade.check_upgrade(urlsrc, regexurl, regexver, currentver, separator, debug, user_login)
    return result
  end

  #### Alias of methods
  
end

# == Schema Information
#
# Table name: package_check_upgrades
#
#  id         :integer          not null, primary key
#  currentver :string(255)
#  output     :text(65535)
#  regexurl   :string(255)
#  regexver   :string(255)
#  separator  :string(255)
#  state      :string           not null
#  urlsrc     :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  package_id :integer          indexed
#
# Indexes
#
#  index_package_check_upgrades_on_package_id  (package_id)
#
