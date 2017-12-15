class Flag < ApplicationRecord
  belongs_to :project, inverse_of: :flags
  belongs_to :package, inverse_of: :flags

  belongs_to :architecture

  scope :of_type, ->(type) { where(flag: type) }

  validates :flag, presence: true
  validates :position, presence: true
  validates :position, numericality: { only_integer: true }

  after_save :discard_forbidden_project_cache
  after_destroy :discard_forbidden_project_cache

  before_validation(on: :create) do
    self.position = main_object.flags.maximum(:position).to_i + 1
  end

  validate :validate_custom_save
  def validate_custom_save
    errors.add(:name, 'Please set either project or package') unless project.nil? ^ package.nil?
    errors.add(:flag, 'There needs to be a valid flag') unless FlagHelper::TYPES.has_key?(flag)
    errors.add(:status, 'Status needs to be enable or disable') unless (status && (status.to_sym == :enable || status.to_sym == :disable))
  end

  validate :validate_duplicates, on: :create
  def validate_duplicates
    flag_exists = Flag.where(
      "status = ? AND repo = ? AND project_id = ? AND package_id = ? AND architecture_id = ? AND flag = ?",
      status,
      repo,
      project_id,
      package_id,
      architecture_id,
      flag
    ).exists?

    errors.add(:flag, "Flag already exists") if flag_exists
  end

  def self.default_status(flag_name)
    case flag_name
    when 'lock', 'debuginfo'
      'disable'
    when 'build', 'publish', 'useforbuild', 'binarydownload', 'access'
      'enable'
    else
      'disable'
    end
  end

  def discard_forbidden_project_cache
    Relationship.discard_cache if flag == 'access'
  end

  def compute_status(variant)
    all_flag = main_object.flags.find_by("flag = ? AND repo IS NULL AND architecture_id IS NULL", flag)
    repo_flag = main_object.flags.find_by("flag = ? AND repo = ? AND architecture_id IS NULL", flag, repo)
    arch_flag = main_object.flags.find_by("flag = ? AND repo IS NULL AND architecture_id = ?", flag, architecture_id)
    same_flag = main_object.flags.find_by("flag = ? AND repo = ? AND architecture_id = ?", flag, repo, architecture_id)
    if main_object.kind_of? Package
      if variant == 'effective'
        same_flag = main_object.project.flags.find_by("flag = ? AND repo = ? AND architecture_id = ?", flag, repo, architecture_id) unless
          all_flag || same_flag || repo_flag || arch_flag
        repo_flag = main_object.project.flags.find_by("flag = ? AND repo = ? AND architecture_id IS NULL", flag, repo) unless
          all_flag || repo_flag || arch_flag
        arch_flag = main_object.project.flags.find_by("flag = ? AND repo IS NULL AND architecture_id = ?", flag, architecture_id) unless
          all_flag || arch_flag
        all_flag = main_object.project.flags.find_by("flag = ? AND repo IS NULL AND architecture_id IS NULL", flag) unless all_flag
      elsif variant == 'default'
        same_flag = main_object.project.flags.find_by("flag = ? AND repo = ? AND architecture_id = ?", flag, repo, architecture_id) unless same_flag
        repo_flag = main_object.project.flags.find_by("flag = ? AND repo = ? AND architecture_id IS NULL", flag, repo) unless repo_flag
        arch_flag = main_object.project.flags.find_by("flag = ? AND repo IS NULL AND architecture_id = ?", flag, architecture_id) unless arch_flag
        all_flag = main_object.project.flags.find_by("flag = ? AND repo IS NULL AND architecture_id IS NULL", flag) unless all_flag
      end
    end

    if variant == 'effective'
      return same_flag.status if same_flag
      return repo_flag.status if repo_flag
      return arch_flag.status if arch_flag
      return all_flag.status if all_flag
    elsif variant == 'default'
      if same_flag
        return repo_flag.status if repo_flag
        return arch_flag.status if arch_flag
      end
      if same_flag || arch_flag || repo_flag
        return all_flag.status if all_flag
      end
      if main_object.kind_of? Package
        all_flag = main_object.project.flags.find_by("flag = ? AND repo IS NULL AND architecture_id IS NULL", flag)
        return all_flag.status if all_flag
      end
    end

    Flag.default_status(flag)
  end
  private :compute_status

  def default_status
    compute_status('default')
  end

  def effective_status
    compute_status('effective')
  end

  def has_children
    repo.blank? || architecture.blank?
  end

  def to_xml(builder)
    raise RuntimeError, "FlagError: No flag-status set. \n #{inspect}" if status.nil?
    options = Hash.new
    options['arch'] = architecture.name unless architecture.nil?
    options['repository'] = repo unless repo.nil?
    builder.send(status.to_s, options)
  end

  def is_explicit_for?(in_repo, in_arch)
    return false unless is_relevant_for?(in_repo, in_arch)

    arch = architecture ? architecture.name : nil

    return false if arch.nil? && in_arch
    return false if arch && in_arch.nil?

    return false if repo.nil? && in_repo
    return false if repo && in_repo.nil?

    true
  end

  # returns true when flag is relevant for the given repo/arch combination
  def is_relevant_for?(in_repo, in_arch)
    arch = architecture ? architecture.name : nil

    return true if arch.nil? && repo.nil?
    return true if arch.nil? && !repo.nil? && in_repo == repo
    return true if arch && repo.nil? && in_arch == arch
    return true if in_arch == arch && in_repo == repo

    false
  end

  def specifics
    count = 0
    count += 1 if status == 'disable'
    count += 2 if architecture
    count += 4 if repo
    count
  end

  def to_s
    ret = status
    ret += " arch=#{architecture.name}" unless architecture.nil?
    ret += " repo=#{repo}" unless repo.nil?
    ret
  end

  def fullname
    ret = flag
    ret += "_#{repo}" if repo.present?
    ret += "_#{architecture.name}" if architecture_id.present?
    ret
  end

  def arch
    architecture.try(:name).to_s
  end

  def main_object
    package || project
  end
end

# == Schema Information
#
# Table name: flags
#
#  id              :integer          not null, primary key
#  status          :string(7)        not null
#  repo            :string(255)
#  project_id      :integer          indexed
#  package_id      :integer          indexed
#  architecture_id :integer          indexed
#  position        :integer          not null
#  flag            :string(14)       not null, indexed
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
