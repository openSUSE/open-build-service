class Flag < ActiveRecord::Base
  belongs_to :project, inverse_of: :flags
  belongs_to :package, inverse_of: :flags

  belongs_to :architecture

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

  validates :flag, :presence => true
  validates :position, :presence => true
  validates_numericality_of :position, :only_integer => true

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
    errors.add(:status, 'Status needs to be enable or disable') unless (self.status && (self.status.to_sym == :enable or self.status.to_sym == :disable))
  end

end
