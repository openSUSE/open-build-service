class Flag < ApplicationRecord
  belongs_to :project, inverse_of: :flags, optional: true
  belongs_to :package, inverse_of: :flags, optional: true

  belongs_to :architecture, optional: true

  scope :of_type, ->(type) { where(flag: type) }

  validates :flag, presence: true
  validates :position, presence: true
  validates :position, numericality: { only_integer: true }

  after_destroy :discard_forbidden_project_cache
  after_save :discard_forbidden_project_cache

  before_validation(on: :create) do
    self.position = main_object.flags.maximum(:position).to_i + 1
  end

  validate :validate_custom_save

  validates :flag, uniqueness: { scope: %i[project_id package_id architecture_id repo], case_sensitive: false }

  def to_xml(builder)
    raise "FlagError: No flag-status set. \n #{inspect}" if status.nil?

    options = {}
    options['arch'] = architecture.name unless architecture.nil?
    options['repository'] = repo unless repo.nil?
    builder.send(status.to_s, options)
  end

  def arch
    architecture.try(:name).to_s
  end

  private

  def discard_forbidden_project_cache
    Relationship.discard_cache if flag == 'access'
  end

  def main_object
    package || project
  end

  def validate_custom_save
    errors.add(:name, 'Please set either project or package') unless project.nil? ^ package.nil?
    errors.add(:flag, 'There needs to be a valid flag') unless FlagHelper::TYPES.key?(flag)
    errors.add(:status, 'Status needs to be enable or disable') unless status && %i[enable disable].include?(status.to_sym)
  end
end

# == Schema Information
#
# Table name: flags
#
#  id              :integer          not null, primary key
#  flag            :string           not null, indexed
#  position        :integer          not null
#  repo            :string(255)
#  status          :string           not null
#  architecture_id :integer          indexed
#  package_id      :integer          indexed
#  project_id      :integer          indexed
#
# Indexes
#
#  architecture_id            (architecture_id)
#  index_flags_on_flag        (flag)
#  index_flags_on_package_id  (package_id)
#  index_flags_on_project_id  (project_id)
#
# Foreign Keys
#
#  flags_ibfk_3  (architecture_id => architectures.id)
#  flags_ibfk_4  (project_id => projects.id)
#  flags_ibfk_5  (package_id => packages.id)
#
