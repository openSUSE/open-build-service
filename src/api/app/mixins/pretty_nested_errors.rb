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
    class_attribute :nested_error_groupings

    def self.nest_errors_for(association_name, options = {})
      self.nested_error_groupings ||= {}
      self.nested_error_groupings[association_name] = options[:by]
    end
  end

  def nested_error_messages
    new_errors = {}

    errors.messages.each do |key, messages|
      double_nested_column = key.match(/(\w+)\[(\d+)\]\.(\w+)\[(\d+)\]\.(\w+)/)
      nested_column = key.match(/(\w+)\[(\d+)\]\.(\w+)/)

      # Matches an error on a nested resource of a nested resource
      # like: {:"package_groups[0].packages[0].name"=>["can't be blank"]}
      if double_nested_column
        association_name = double_nested_column[1].to_sym
        association_index = double_nested_column[2].to_i
        sub_association_name = double_nested_column[3].to_sym
        sub_association_index = double_nested_column[4].to_i
        association_invalid_column = double_nested_column[5]

        # Find the association record
        record = send(association_name)[association_index].send(sub_association_name)[sub_association_index]

        # Call the lambda method to determine the grouping
        group_by = self.nested_error_groupings["#{association_name}_#{sub_association_name}".to_sym].call(record)

        new_errors[group_by] ||= []
        new_errors[group_by] +=
          messages.map { |message| errors.full_message(association_invalid_column, message) }

      # Matches an error on a nested resource
      # like {:"repositories[0].source_path"=>["can't be blank"]}
      elsif nested_column

        association_name = nested_column[1].to_sym
        association_index = nested_column[2].to_i
        association_invalid_column = nested_column[3]

        # Find the association record
        record = send(association_name)[association_index]

        # Call the lambda method to determine the grouping
        group_by = self.nested_error_groupings[association_name].call(record)

        new_errors[group_by] ||= []
        new_errors[group_by] +=
          messages.map { |message| errors.full_message(association_invalid_column, message) }

      # Matches an error on the base resource like: {:"name"=>["can't be blank"]}
      else
        group_by = self.class.name.humanize

        new_errors[group_by] ||= []
        new_errors[group_by] +=
          messages.map { |message| errors.full_message(key, message) }
      end
    end
    new_errors
  end
end
