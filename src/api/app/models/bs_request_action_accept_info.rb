class BsRequestActionAcceptInfo < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :bs_request_action

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  #### Validations macros
  #### Class methods using self. (public and then private)
  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def render_xml(builder)
    attributes = { rev: rev, srcmd5: srcmd5 }
    attributes[:oproject] = oproject unless oproject.blank?
    attributes[:opackage] = opackage unless opackage.blank?
    attributes[:osrcmd5] = osrcmd5 unless osrcmd5.blank?
    attributes[:xsrcmd5] = xsrcmd5 unless xsrcmd5.blank?
    attributes[:oxsrcmd5] = oxsrcmd5 unless oxsrcmd5.blank?
    builder.acceptinfo attributes
  end

  #### Alias of methods
end

