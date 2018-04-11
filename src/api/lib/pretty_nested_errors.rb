# frozen_string_literal: true

require 'pretty_nested_errors/key_and_messages_parser'
#  PrettyNestedErrors
#
#  Groups errors for nested resources on a model by a lambda for each nested resource.
#  Example:
#
#    class Kiwi::Image < ApplicationRecord
#      include PrettyNestedErrors
#
#      has_many :repositories, index_errors: true
#      has_many :package_groups, index_errors: true
#
#      accepts_nested_attributes_for :repositories
#      accepts_nested_attributes_for :package_groups
#
#      validates_presence_of :name
#
#      nest_errors_for :package_groups_packages, by: lambda { |kiwi_package| "Package: #{kiwi_package.name}" }
#      nest_errors_for :repositories, by: lambda { |repository| "Repository: #{repository.source_path}" }
#    end
#
#    class Kiwi::Repository < ApplicationRecord
#      belongs_to :image
#
#      validates_presence_of :source_path
#      validates_numericality_of :priority
#    end
#
#    class Kiwi::PackageGroup < ApplicationRecord
#      belongs_to :image
#      has_many :packages, index_errors: true

#      accepts_nested_attributes_for :packages
#    end
#
#    class Kiwi::Package < ApplicationRecord
#      belongs_to :package_group
#      has_many :packages, index_errors: true
#
#      validates_presence_of :name
#      validates_inclusion_of :name, in: %(valid list of names)
#    end
#
#  So saving a Kiwi::Image with invalid data, might result in a kiwi image with these errors:
#    kiwi_image.errors.messages =>
#      {
#        :"package_groups[0].packages[0].name" => ["can't be blank", "must be in list of valid names"],
#        :"repositories[0].source_path" => ["can't be blank"],
#        :"repositories[0].priority" => ["must be between a number"],
#        :"name" => ["can't be blank"],
#      }
#
#  Those errors are not easy to read, but if we call kiwi_image.nested_error_messages we get something better:
#    kiwi_image.nested_error_messages =>
#      {
#        "Package: " => [
#          "Name can't be blank",
#          "Name must be in list of valid names"
#        ],
#        "Repository: obs://SUSE:SLE-1x2-SP3:Update/WE" => [
#          "Source path can't be blank",
#          "Priority must be between a number"
#        ],
#        "Image:" => [
#          "Name can't be blank"
#        ]
#      }
module PrettyNestedErrors
  extend ActiveSupport::Concern

  included do
    attr_reader :nested_error_messages
    class_attribute :nested_error_groupings

    def self.nest_errors_for(association_name, options = {})
      self.nested_error_groupings ||= {}
      self.nested_error_groupings[association_name] = options[:by]
    end

    after_validation :generate_nested_error_messages
  end

  def generate_nested_error_messages
    @nested_error_messages = {}
    errors.messages.each do |key, messages|
      @nested_error_messages =
        KeyAndMessagesParser.new(self, key, messages, @nested_error_messages, self.nested_error_groupings).parse
    end
    @nested_error_messages
  end
end
