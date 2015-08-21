class ValueLengthValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && record.attrib_type.value_count && record.attrib_type.value_count != record.values.length
      record.errors[:values] << "has #{record.values.length} values, but only #{record.attrib_type.value_count} are allowed"
    end
  end
end

class IssueValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && !record.attrib_type.issue_list and record.issues.any?
      record.errors[:issues] << "can't have issues"
    end
  end
end

class AllowedValuesValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && record.attrib_type.allowed_values.any?
      record.values.each do |value|
        found = false
        record.attrib_type.allowed_values.each do |allowed|
          if allowed.value == value.value
            found = true
            break
          end
        end
        if !found
          record.errors[:values] << "value \'#{value}\' is not allowed. Please use one of: " +
                                    "#{record.attrib_type.allowed_values.map{|av| av.value }.join(', ')}"
        end
      end
    end
  end
end

# Attribute container inside package meta data
# Attribute definitions are inside attrib_type
class Attrib < ActiveRecord::Base
  #### Includes and extends
  #### Constants
  #### Self config
  accepts_nested_attributes_for :values, allow_destroy: true
  accepts_nested_attributes_for :issues, allow_destroy: true

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

  #### Callbacks macros: before_save, after_save, etc.
  #### Scopes (first the default_scope macro if is used)
  scope :nobinary, -> { where(binary: nil) }

  #### Validations macros
  validates_associated :values
  validates_associated :issues
  validates :attrib_type, presence: true
  # Either we belong to a project or to a package
  validates :package, presence: true, if: "project_id.nil?"
  validates :package_id, :absence => {:message => "can't also be present"}, if: "project_id.present?"
  validates :project, presence: true, if: "package_id.nil?"

  validates_with ValueLengthValidator
  validates_with IssueValidator
  validates_with AllowedValuesValidator

  #### Class methods using self. (public and then private)
  def self.find_by_container_and_fullname( container, fullname )
    container.attribs.where(attrib_type: AttribType.find_by_name!(fullname)).first
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
    !attrib_type.value_count ||  # If unlimited values
    (attrib_type.value_count && attrib_type.value_count > 0) ||  # If value_count > 0
    attrib_type.issue_list  # If issue_list true
  end

  def values_removeable?
    !attrib_type.value_count ||  # If unlimited values
    (attrib_type.value_count && (attrib_type.value_count != values.length))  # If value_count != values.length
  end

  def cachekey
    key = "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    key += "|#{binary}" if binary
  end

  def update_with_associations(new_values = [], new_issues = [])
    will_save = false

    #--- update issues ---#
    if new_issues.map { |i| i.name }.sort != self.issues.map { |i| i.name }.sort
      logger.debug "Attrib.update_with_associations: Issues for #{self.fullname} changed, updating."
      will_save = true
      self.issues.delete_all
      new_issues.each do |issue|
        self.issues << issue
      end
    end

    #--- update values ---#
    if new_values.sort != self.values.map { |v| v.value}.sort
      logger.debug "Attrib.update_with_associations: Values for #{self.fullname} changed, updating."
      will_save = true
      self.values.delete_all
      position = 1
      new_values.each do |val|
        self.values.create(value: val, position: position)
        position += 1
      end
    end

    save! if will_save
    will_save
  end

  #### Alias of methods
  alias :values_addable? :values_removeable?

end
