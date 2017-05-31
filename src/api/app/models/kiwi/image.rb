# TODO: Please overwrite this comment with something explaining the model target
class Kiwi::Image < ApplicationRecord
  #### Includes and extends

  #### Constants

  #### Self config

  #### Attributes

  #### Associations macros (Belongs to, Has one, Has many)
  has_one :package, foreign_key: 'kiwi_image_id', dependent: :nullify
  has_many :repositories, -> { order(order: :asc) }, dependent: :destroy, index_errors: true

  #### Callbacks macros: before_save, after_save, etc.

  #### Scopes (first the default_scope macro if is used)

  #### Validations macros
  validates :name, presence: true
  accepts_nested_attributes_for :repositories

  #### Class methods using self. (public and then private)

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)

  #### Alias of methods
  def self.build_from_xml(xml_string, md5)
    xml = Xmlhash.parse(xml_string)
    new_image = new(name: xml['name'], md5_last_revision: md5)
    order = 1
    xml["repository"].each do |repository|
      attributes = {
        repo_type:   repository['type'],
        source_path: repository['source']['path'],
        priority:    repository['priority'],
        order:       order,
        alias:       repository['alias'],
        replaceable: repository['status'] == 'replaceable',
        username:    repository['username'],
        password:    repository['password']
      }
      attributes['imageinclude'] = repository['imageinclude'] == 'true' if repository.key?('imageinclude')
      attributes['prefer_license'] = repository['prefer-license'] == 'true' if repository.key?('prefer-license')

      new_image.repositories.build(attributes)
      order += 1
    end
    new_image
  end
end

# == Schema Information
#
# Table name: kiwi_images
#
#  id                :integer          not null, primary key
#  name              :string(255)
#  md5_last_revision :string(32)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
