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
          record.errors[:values] << "value \'#{value}\' is not allowed. Please use one of: #{record.attrib_type.allowed_values.map{|av| av.value }.join(', ')}"
        end
      end
    end
  end
end

# Attribute container inside package meta data
# Attribute definitions are inside attrib_type

class Attrib < ActiveRecord::Base
  belongs_to :package
  belongs_to :project
  belongs_to :attrib_type
  has_many :attrib_issues
  has_many :issues, through: :attrib_issues, dependent: :destroy
  has_many :values, -> { order("position ASC") }, class_name: 'AttribValue', dependent: :delete_all
  accepts_nested_attributes_for :values, allow_destroy: true
  accepts_nested_attributes_for :issues, allow_destroy: true

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

  delegate :name, to: :attrib_type
  delegate :namespace, to: :attrib_type

  scope :nobinary, -> { where(:binary => nil) }

  def self.find_by_container_and_fullname( container, fullname )
    atype = AttribType.find_by_name!(fullname)
    return container.attribs.where(attrib_type: atype).first
  end

  def fullname
    return "#{self.namespace}:#{self.name}"
  end

  def container
    if self.package_id
      return self.package
    elsif self.project_id
      return self.project
    end
  end

  def project
    if package
      return package.project
    else
      super
    end
  end

  def values_editable?
    ret = false

    # If unlimited values
    ret = true if !self.attrib_type.value_count
    # If value_count > 0
    ret = true if self.attrib_type.value_count && self.attrib_type.value_count > 0
    # If issue_list true
    ret = true if self.attrib_type.issue_list

    return ret
  end

  def values_removeable?
    ret = false

    # If unlimited values
    ret = true if !self.attrib_type.value_count
    # If value_count != values.length
    ret = true if self.attrib_type.value_count and (self.attrib_type.value_count != self.values.length)

    return ret
  end
  alias :values_addable? :values_removeable?

  def cachekey
    if binary
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}|#{binary}"
    else
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    end
  end

  def update_with_associations(values = [], issues = [])
    save = false

    #--- update issues ---#
    if issues.map { |i| i.name }.sort != self.issues.map { |i| i.name }.sort
      logger.debug "Attrib.update_with_associations: Issues for #{self.fullname} changed, updating."
      save = true
      self.issues.delete_all
      issues.each do |issue|
        self.issues << issue
      end
    end

    #--- update values ---#
    if values.sort != self.values.map { |v| v.value}.sort
      logger.debug "Attrib.update_with_associations: Values for #{self.fullname} changed, updating."
      save = true
      self.values.delete_all
      position = 1
      values.each do |val|
        self.values.create(value: val, position: position)
        position += 1
      end
    end

    self.save! if save
    return save
  end

end
