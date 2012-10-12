require 'rexml/document'

class Flag < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :db_package

  belongs_to :architecture

  attr_accessible :repo, :status, :flag, :position, :architecture, :db_project, :db_package

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
    if self.db_project
      self.position = (self.db_project.flags.maximum(:position) || 0 ) + 1
    elsif self.db_package
      self.position = (self.db_package.flags.maximum(:position) || 0 ) + 1
    end
  end

  validate :validate_custom_save
  def validate_custom_save
    errors.add(:name, "Please set either project_id or package_id.") if self.db_project.nil? and self.db_package.nil?
    errors.add(:flag, "There needs to be a valid flag.") unless FlagHelper::TYPES.has_key?(self.flag)
    errors.add(:status, "Status needs to be enable or disable") unless (self.status == 'enable' or self.status == 'disable')
    errors.add(:name, "Please set either project_id or package_id.") unless self.db_project_id.nil? or self.db_package_id.nil?
  end

end
