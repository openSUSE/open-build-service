# typed: strict
module Kiwi
  class Profile < ApplicationRecord
    #### Includes and extends

    #### Constants

    #### Self config

    #### Attributes

    #### Associations macros (Belongs to, Has one, Has many)
    belongs_to :image, inverse_of: :profiles

    #### Callbacks macros: before_save, after_save, etc.

    #### Scopes (first the default_scope macro if is used)
    scope :selected, -> { where(selected: true) }

    #### Validations macros
    validates :name, presence: true
    validates :description, presence: true
    validates :image, presence: true
    validates :selected, inclusion: { in: [true, false] }
    validates :name, uniqueness: {
      scope: :image,
      message: lambda do |object, data|
        "#{data[:value]} has already been taken for the Image ##{object.image_id}"
      end
    }

    #### Class methods using self. (public and then private)

    #### To define class methods as private use private_class_method
    #### private

    #### Instance methods (public and then protected/private)

    #### Alias of methods
  end
end
