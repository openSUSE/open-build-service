class Flag < ApplicationRecord
  belongs_to :project, inverse_of: :flags
  belongs_to :package, inverse_of: :flags

  belongs_to :architecture

  scope :of_type, ->(type) { where(flag: type) }

  validates :flag, :presence => true
  validates :position, :presence => true
  validates_numericality_of :position, :only_integer => true

  after_save :discard_forbidden_project_cache
  after_destroy :discard_forbidden_project_cache

  before_validation(:on => :create) do
    if self.project
      self.position = (self.project.flags.maximum(:position) || 0 ) + 1
    elsif self.package
      self.position = (self.package.flags.maximum(:position) || 0 ) + 1
    end
  end

  validate :validate_custom_save
  def validate_custom_save
    errors.add(:name, 'Please set either project or package.') if self.project.nil? and self.package.nil?
    errors.add(:name, 'Please set either project or package.') unless self.project.nil? or self.package.nil?
    errors.add(:flag, 'There needs to be a valid flag.') unless FlagHelper::TYPES.has_key?(self.flag.to_s)
    # rubocop:disable Metrics/LineLength
    errors.add(:status, 'Status needs to be enable or disable') unless (self.status && (self.status.to_sym == :enable or self.status.to_sym == :disable))
    # rubocop:enable Metrics/LineLength
  end

  validate :validate_duplicates, :on => :create
  def validate_duplicates
    # rubocop:disable Metrics/LineLength
    if Flag.where("status = ? AND repo = ? AND project_id = ? AND package_id = ? AND architecture_id = ? AND flag = ?", self.status, self.repo, self.project_id, self.package_id, self.architecture_id, self.flag).exists?
      errors.add(:flag, "Flag already exists")
    end
    # rubocop:enable Metrics/LineLength
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
    Relationship.discard_cache if self.flag == 'access'
  end

  def default_status
    all_flag = main_object.flags.where("flag = ? AND repo IS NULL AND architecture_id IS NULL", self.flag).first
    repo_flag = main_object.flags.where("flag = ? AND repo = ? AND architecture_id IS NULL", self.flag, self.repo).first
    arch_flag = main_object.flags.where("flag = ? AND repo IS NULL AND architecture_id = ?", self.flag, self.architecture_id).first

    # Package settings only override project settings...
    if main_object.kind_of? Package
      all_flag = main_object.project.flags.where("flag = ? AND repo IS NULL AND architecture_id IS NULL", self.flag).first unless all_flag
      repo_flag = main_object.project.flags.where("flag = ? AND repo = ? AND architecture_id IS NULL", self.flag, self.repo).first unless repo_flag
      arch_flag = main_object.project.flags.where("flag = ?
                                                   AND repo IS NULL
                                                   AND architecture_id = ?", self.flag, self.architecture_id).first unless arch_flag
      same_flag = main_object.project.flags.where("flag = ?
                                                   AND repo = ?
                                                   AND architecture_id = ?", self.flag, self.repo, self.architecture_id).first
    end

    return same_flag.status if same_flag
    return repo_flag.status if repo_flag
    return arch_flag.status if arch_flag
    return all_flag.status if all_flag
    return Flag.default_status(self.flag)
  end

  def has_children
    return true if repo.blank? && architecture.blank?
    return true if !repo.blank? && architecture.blank?
    return true if repo.blank? && !architecture.blank?
    return false
  end

  def to_xml(builder)
    raise RuntimeError.new( "FlagError: No flag-status set. \n #{self.inspect}" ) if self.status.nil?
    options = Hash.new
    options['arch'] = self.architecture.name unless self.architecture.nil?
    options['repository'] = self.repo unless self.repo.nil?
    builder.send(status.to_s, options)
  end

  def is_explicit_for?(in_repo, in_arch)
    return false unless is_relevant_for?(in_repo, in_arch)

    arch = architecture ? architecture.name : nil

    return false if arch.nil? and !in_arch.nil?
    return false if !arch.nil? and in_arch.nil?

    return false if repo.nil? and !in_repo.nil?
    return false if !repo.nil? and in_repo.nil?

    return true
  end

  # returns true when flag is relevant for the given repo/arch combination
  def is_relevant_for?(in_repo, in_arch)
    arch = architecture ? architecture.name : nil

    if arch.nil? and repo.nil?
      return true
    elsif arch.nil? and not repo.nil?
      return true if in_repo == repo
    elsif not arch.nil? and repo.nil?
      return true if in_arch == arch
    else
      return true if in_arch == arch and in_repo == repo
    end

    return false
  end

  def specifics
    count = 0
    count += 1 if status == 'disable'
    count += 2 unless architecture.nil?
    count += 4 unless repo.nil?
    count
  end

  def to_s
    ret = status
    ret += " arch=#{self.architecture.name}" unless self.architecture.nil?
    ret += " repo=#{self.repo}" unless self.repo.nil?
    ret
  end

  def fullname
    ret = self.flag
    ret += "_#{repo}" unless repo.blank?
    ret += "_#{architecture.name}" unless architecture_id.blank?
    ret
  end

  def arch
    architecture_id.blank? ? '' : architecture.name
  end

  def main_object
    self.package || self.project
  end
end
