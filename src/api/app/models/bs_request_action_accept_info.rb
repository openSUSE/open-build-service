# frozen_string_literal: true

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
    attributes = { rev: rev, srcmd5: srcmd5 }
    attributes[:oproject] = oproject if oproject.present?
    attributes[:opackage] = opackage if opackage.present?
    attributes[:osrcmd5] = osrcmd5 if osrcmd5.present?
    attributes[:xsrcmd5] = xsrcmd5 if xsrcmd5.present?
    attributes[:oxsrcmd5] = oxsrcmd5 if oxsrcmd5.present?
    builder.acceptinfo attributes
  end

  #### Alias of methods
end

# == Schema Information
#
# Table name: bs_request_action_accept_infos
#
#  id                   :integer          not null, primary key
#  bs_request_action_id :integer          indexed
#  rev                  :string(255)
#  srcmd5               :string(255)
#  xsrcmd5              :string(255)
#  osrcmd5              :string(255)
#  oxsrcmd5             :string(255)
#  created_at           :datetime
#  oproject             :string(255)
#  opackage             :string(255)
#
# Indexes
#
#  bs_request_action_id  (bs_request_action_id)
#
# Foreign Keys
#
#  bs_request_action_accept_infos_ibfk_1  (bs_request_action_id => bs_request_actions.id)
#
