class BackendPackage < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  self.primary_key = 'package_id' # a package can have one target _link (or not)

  #### Attributes
  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :links_to, class_name: 'Package'
  belongs_to :package, inverse_of: :backend_package

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  scope :links, -> { where('links_to_id is not null') }
  scope :not_links, -> { where('links_to_id is null') }

  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private
  #### Instance methods (public and then protected/private)
  #### Alias of methods
end
