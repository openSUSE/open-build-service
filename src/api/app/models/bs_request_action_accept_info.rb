#
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
    attributes = { :rev => self.rev, :srcmd5 => self.srcmd5 }
    attributes[:oproject] = self.oproject unless self.oproject.blank?
    attributes[:opackage] = self.opackage unless self.opackage.blank?
    attributes[:osrcmd5] = self.osrcmd5 unless self.osrcmd5.blank?
    attributes[:xsrcmd5] = self.xsrcmd5 unless self.xsrcmd5.blank?
    attributes[:oxsrcmd5] = self.oxsrcmd5 unless self.oxsrcmd5.blank?
    builder.acceptinfo attributes
  end

  #### Alias of methods
end
