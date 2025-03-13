# Attribute container inside package meta data. Attribute definitions are inside attrib_type
class Attrib < ApplicationRecord
  #### Includes and extends
  #### Constants
  #### Self config
  #### Attributes
  delegate :name, to: :attrib_type
  delegate :namespace, to: :attrib_type

  #### Associations macros (Belongs to, Has one, Has many)
  belongs_to :package, optional: true
  belongs_to :project, optional: true
  belongs_to :attrib_type
  has_many :attrib_issues
  has_many :issues, through: :attrib_issues, dependent: :destroy
  has_many :values, -> { order('position ASC') }, class_name: 'AttribValue', dependent: :delete_all

  accepts_nested_attributes_for :values, allow_destroy: true
  accepts_nested_attributes_for :issues, allow_destroy: true

  #### Validations macros
  validates_associated :values
  validates_associated :issues
  # Either we belong to a project or to a package
  validates :binary, length: { maximum: 255 }
  validates :package, presence: true, if: proc { |attrib| attrib.project_id.nil? }
  validates :package_id, absence: { message: "can't also be present" }, if: proc { |attrib| attrib.project_id.present? }
  validates :project, presence: true, if: proc { |attrib| attrib.package_id.nil? }

  validate :validate_value_count,
           :validate_embargo_date_value,
           :validate_issues,
           :validate_allowed_values_for_attrib_type

  after_save :populate_to_sphinx
  after_commit :write_container_attributes, on: %i[create destroy update]

  #### Class methods using self. (public and then private)
  def self.find_by_container_and_fullname(container, fullname)
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

  def container=(container_object)
    if container_object.is_a?(Project)
      self.project = container_object
    else
      self.package = container_object
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
      (attrib_type.value_count && attrib_type.value_count.positive?) || # If value_count.positive?
      attrib_type.issue_list # If issue_list true
  end

  def values_removeable?
    !attrib_type.value_count || # If unlimited values
      (attrib_type.value_count && (attrib_type.value_count != values.length)) # If value_count != values.length
  end

  def update_with_associations(values = [], issues = [])
    #--- update issues ---#
    changed = false
    if issues.map(&:name).sort! != self.issues.map(&:name).sort!
      logger.debug "Attrib.update_with_associations: Issues for #{fullname} changed, updating."
      self.issues.delete_all
      issues.each do |issue|
        self.issues << issue
      end
      changed = true
    end

    #--- update values ---#
    if values != self.values.map(&:value)
      logger.debug "Attrib.update_with_associations: Values for #{fullname} changed, updating."
      self.values.delete_all
      position = 1
      values.each do |val|
        self.values.build(value: val, position: position)
        position += 1
      end
      changed = true
    end

    save!
    saved_changes? || changed
  end

  #### Alias of methods
  alias values_addable? values_removeable?

  def embargo_date
    return unless attrib_type && name == 'EmbargoDate'
    return unless valid?
    return if values&.first&.value.blank?

    attribute_value = values.first&.value
    embargo_date = Time.zone.parse(attribute_value)
    # No time set in the value, embargo it until the beginning of the next day
    embargo_date = embargo_date.tomorrow if /^\d{4}-\d\d?-\d\d?$/.match?(attribute_value)

    embargo_date
  end

  private

  def check_timezone_identifier(value)
    # Check for a valid timezone identifier
    if value =~ /\A\d{4}-\d\d?-\d\d?(\s|T)\d\d?:\d\d?(:\d\d?)?\s(.+)\Z/ &&  # whole string matches 'YYYY-MM-DD HH:MM:SS TZ' and
       (timezone = Regexp.last_match(3)) !~ /(\+|-)\d\d?(:\d\d?)?/          # timezone part doesn't match '+-HH:MM'
      begin
        TZInfo::Timezone.get(timezone)
      rescue TZInfo::InvalidTimezoneIdentifier
        errors.add(:embargo_date, :invalid_date, message: "Value '#{value}' contains a non-valid timezone")
        return false
      end
    end

    true
  end

  def parse_value(value)
    begin
      parsed_value = Time.zone.parse(value)
    rescue ArgumentError => e
      errors.add(:embargo_date, :invalid_date, message: "Value '#{value}' couldn't be parsed: '#{e.message}'")
      return false
    end

    if parsed_value.nil?
      errors.add(:embargo_date, :invalid_date, message: "Value '#{value}' couldn't be parsed")
      return false
    end

    true
  end

  def validate_allowed_values_for_attrib_type
    return unless attrib_type && attrib_type.allowed_values.any?

    values.map(&:value).each do |value|
      allowed_values = attrib_type.allowed_values.map(&:value)
      errors.add(:values, "Value '#{value}' is not allowed. Please use one of: #{allowed_values.join(', ')}") unless allowed_values.include?(value)
    end
  end

  def validate_issues
    errors.add(:issues, "can't have issues") if attrib_type && !attrib_type.issue_list && issues.any?
  end

  def validate_value_count
    value_count = attrib_type.try(:value_count)
    errors.add(:values, "has #{values.length} values, but only #{value_count} are allowed") if value_count && value_count != values.length
  end

  def validate_embargo_date_value
    return unless attrib_type && name == 'EmbargoDate'

    value = values[0]&.value
    return if value.blank?

    parse_value(value) && check_timezone_identifier(value)
  end

  def write_container_attributes
    container.write_attributes if container && !container.destroyed?
  end

  def populate_to_sphinx
    return unless package_id_previously_changed? || project_id_previously_changed?

    if package_id_previously_changed?
      PopulateToSphinxJob.perform_later(id: id, model_name: :attrib, reference: :package, path: [:package])
    else
      PopulateToSphinxJob.perform_later(id: id, model_name: :attrib, reference: :project, path: [:project])
    end
  end
end

# == Schema Information
#
# Table name: attribs
#
#  id             :integer          not null, primary key
#  binary         :string(255)      indexed => [attrib_type_id, package_id, project_id], indexed => [attrib_type_id, project_id, package_id]
#  attrib_type_id :integer          not null, indexed => [package_id, project_id, binary], indexed => [project_id, package_id, binary]
#  package_id     :integer          indexed => [attrib_type_id, project_id, binary], indexed => [attrib_type_id, project_id, binary], indexed
#  project_id     :integer          indexed => [attrib_type_id, package_id, binary], indexed => [attrib_type_id, package_id, binary], indexed
#
# Indexes
#
#  attribs_index                (attrib_type_id,package_id,project_id,binary) UNIQUE
#  attribs_on_proj_and_pack     (attrib_type_id,project_id,package_id,binary) UNIQUE
#  index_attribs_on_package_id  (package_id)
#  index_attribs_on_project_id  (project_id)
#
# Foreign Keys
#
#  attribs_ibfk_1  (attrib_type_id => attrib_types.id)
#  attribs_ibfk_2  (package_id => packages.id)
#  attribs_ibfk_3  (project_id => projects.id)
#
