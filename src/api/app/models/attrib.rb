# Attribute container inside package meta data. Attribute definitions are inside attrib_type
class Attrib < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  delegate :name, to: :attrib_type
  delegate :namespace, to: :attrib_type

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :package
  belongs_to :project
  belongs_to :attrib_type
  has_many :attrib_issues
  has_many :issues, through: :attrib_issues, dependent: :destroy
  has_many :values, -> { order("position ASC") }, class_name: 'AttribValue', dependent: :delete_all

  accepts_nested_attributes_for :values, allow_destroy: true
  accepts_nested_attributes_for :issues, allow_destroy: true

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  scope :nobinary, -> { where(binary: nil) }

  #### Validations macros
  validates_associated :values
  validates_associated :issues
  validates :attrib_type, presence: true
  # Either we belong to a project or to a package
  validates :package, presence: true, if: "project_id.nil?"
  validates :package_id, absence: {message: "can't also be present"}, if: "project_id.present?"
  validates :project, presence: true, if: "package_id.nil?"

  validate :validate_value_count,
           :validate_issues,
           :validate_allowed_values_for_attrib_type

  #### Class methods using self. (public and then private)
  def self.find_by_container_and_fullname( container, fullname )
    container.attribs.find_by(attrib_type: AttribType.find_by_name!(fullname))
  end

  #### To define class methods as private use private_class_method
  #### private

  #### Instance methods (public and then protected/private)
  def fullname
    "#{namespace}:#{name}"
  end

  def container
    if package_id
      package
    elsif project_id
      project
    end
  end

  def project
    if package
      package.project
    else
      super
    end
  end

  def values_editable?
    !attrib_type.value_count || # If unlimited values
      (attrib_type.value_count && attrib_type.value_count > 0) || # If value_count > 0
      attrib_type.issue_list # If issue_list true
  end

  def values_removeable?
    !attrib_type.value_count || # If unlimited values
      (attrib_type.value_count && (attrib_type.value_count != values.length)) # If value_count != values.length
  end

  def cachekey
    key = "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    key + "|#{binary}" if binary
  end

  def update_with_associations(values = [], issues = [])
    will_save = false

    #--- update issues ---#
    if issues.map { |i| i.name }.sort != self.issues.map { |i| i.name }.sort
      logger.debug "Attrib.update_with_associations: Issues for #{fullname} changed, updating."
      will_save = true
      self.issues.delete_all
      issues.each do |issue|
        self.issues << issue
      end
    end

    #--- update values ---#
    if values.sort != self.values.map { |v| v.value}.sort
      logger.debug "Attrib.update_with_associations: Values for #{fullname} changed, updating."
      will_save = true
      self.values.delete_all
      position = 1
      values.each do |val|
        self.values.create(value: val, position: position)
        position += 1
      end
    end

    save! if will_save
    will_save
  end

  #### Alias of methods
  alias :values_addable? :values_removeable?

  private

  def validate_value_count
    if attrib_type && attrib_type.allowed_values.any?
      values.map(&:value).each do |value|
        allowed_values = attrib_type.allowed_values.map(&:value)
        unless allowed_values.include?(value)
          errors[:values] <<
            "Value '#{value}' is not allowed. Please use one of: #{allowed_values.join(', ')}"
        end
      end
    end
  end

  def validate_issues
    if attrib_type && !attrib_type.issue_list && issues.any?
      errors[:issues] << "can't have issues"
    end
  end

  def validate_allowed_values_for_attrib_type
    value_count = attrib_type.try(:value_count)
    if value_count && value_count != values.length
      errors[:values] << "has #{values.length} values, but only #{value_count} are allowed"
    end
  end
end
