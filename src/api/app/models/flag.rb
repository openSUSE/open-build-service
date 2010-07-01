require 'rexml/document'

class Flag < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :db_package

  belongs_to :architecture

  def to_xml(builder)
    raise RuntimeError.new( "FlagError: No flag-status set. \n #{self.inspect}" ) if self.status.nil?
    options = Hash.new
    options['arch'] = self.architecture.name unless self.architecture.nil?
    options['repository'] = self.repo unless self.repo.nil?
    builder.tag! self.status.to_s, options
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
    count += 1 unless architecture.nil?
    count += 1 unless repo.nil?
    count
  end

  def to_s
    ret = status
    ret += " arch=#{self.architecture.name}" unless self.architecture.nil?
    ret += " repo=#{self.repo}" unless self.repo.nil?
    ret
  end

  def state
    (status+"d").to_sym
  end

  class << self
    def default_state(state=nil)
      if state
        @@default_state = state
      end
      @@default_state
    end
  end


  protected
  def validate
    errors.add("name", "Please set either project_id or package_id.") unless self.db_project_id.nil? or self.db_package_id.nil?
    errors.add("name", "Please set either project_id or package_id.") if self.db_project_id.nil? and self.db_package_id.nil?
    errors.add("flag", "There needs to be a flag.") if self.flag.nil?
    if self.position.nil?
      if self.db_project
	self.position = (self.db_project.flags.maximum(:position) || 0 ) + 1
      else
	self.position = (self.db_package.flags.maximum(:position) || 0 ) + 1
      end
      errors.add("position", "position is not set") if self.position.nil?
    end
  end

end
