# -*- coding: utf-8 -*-
class BsRequestAction < ActiveRecord::Base

  belongs_to :bs_request
  has_one :bs_request_action_accept_info, :dependent => :delete

  validates_inclusion_of :action_type, :in => [:submit, :delete, :change_devel, :add_role, :set_bugowner, 
                                               :maintenance_incident, :maintenance_release]
  VALID_SOURCEUPDATE_OPTIONS = ["update", "noupdate", "cleanup"]
  validates_inclusion_of :sourceupdate, :in => VALID_SOURCEUPDATE_OPTIONS, :allow_nil => true

  attr_accessible :source_package, :source_project, :source_rev, :target_package, :target_releaseproject,
                  :target_project, :action_type, :bs_request_id, :sourceupdate, :updatelink, :person_name, :group_name, :role

  validate :check_sanity
  def check_sanity
    if [:submit, :maintenance_incident, :maintenance_release, :change_devel].include? action_type
      errors.add(:source_project, "should not be empty for #{action_type} requests") if source_project.blank?
      if action_type != :maintenance_incident
        errors.add(:source_package, "should not be empty for #{action_type} requests") if source_package.blank?
      end
      errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
    end
    if action_type == :add_role
      errors.add(:role, "should not be empty for add_role") if role.blank?
      if person_name.blank? && group_name.blank?
        errors.add(:person_name, "Either person or group needs to be set")
      end
    end
    # TODO to be continued
  end

  def action_type
    read_attribute(:action_type).to_sym
  end

  def self.new_from_xml_hash(hash)
    a = BsRequestAction.new
    a.action_type = hash.delete("type").to_sym

    source = hash.delete("source")
    if source
      a.source_package = source.delete("package")
      a.source_project = source.delete("project")
      a.source_rev     = source.delete("rev")

      raise ArgumentError, "too much information #{source.inspect}" unless source.blank?
    end

    target = hash.delete("target")
    if target
      a.target_package = target.delete("package")
      a.target_project = target.delete("project")
      a.target_releaseproject = target.delete("releaseproject")

      raise ArgumentError, "too much information #{target.inspect}" unless target.blank?
    end

    ai = hash.delete("acceptinfo")
    if ai
      a.bs_request_action_accept_info = BsRequestActionAcceptInfo.new
      a.bs_request_action_accept_info.rev = ai.delete("rev")
      a.bs_request_action_accept_info.srcmd5 = ai.delete("srcmd5")
      a.bs_request_action_accept_info.osrcmd5 = ai.delete("osrcmd5")
      a.bs_request_action_accept_info.xsrcmd5 = ai.delete("xsrcmd5")
      a.bs_request_action_accept_info.oxsrcmd5 = ai.delete("oxsrcmd5")

      raise ArgumentError, "too much information #{ai.inspect}" unless ai.blank?
    end

    o = hash.delete("options")
    if o
      a.sourceupdate = o.delete("sourceupdate")
      # old form
      a.sourceupdate = "update" if a.sourceupdate == "1"
      # there is mess in old data ;(
      a.sourceupdate = nil unless VALID_SOURCEUPDATE_OPTIONS.include? a.sourceupdate

      a.updatelink = true if o.delete("updatelink") == "true"
      raise ArgumentError, "too much information #{s.inspect}" unless o.blank?
    end

    p = hash.delete("person")
    if p
      a.person_name = p.delete("name") { raise ArgumentError, "a person without name" }
      a.role = p.delete("role")
      raise ArgumentError, "too much information #{p.inspect}" unless p.blank?
    end

    g = hash.delete("group")
    if g 
      a.group_name = g.delete("name") { raise ArgumentError, "a group without name" }
      raise ArgumentError, "role already taken" if a.role
      a.role = g.delete("role")
      raise ArgumentError, "too much information #{g.inspect}" unless g.blank?
    end

    raise ArgumentError, "too much information #{hash.inspect}" unless hash.blank?
    
    a
  end

  def render_xml(builder)
    builder.action :type => self.action_type do |action|
      if [:submit, :maintenance_incident, :maintenance_release, :change_devel].include? self.action_type
        attributes = {}
        attributes[:project] = self.source_project unless self.source_project.blank?
        attributes[:package] = self.source_package unless self.source_package.blank?
        attributes[:rev] = self.source_rev unless self.source_rev.blank?
        action.source attributes
        attributes = {}
        attributes[:project] = self.target_project unless self.target_project.blank?
        attributes[:package] = self.target_package unless self.target_package.blank?
        attributes[:releaseproject] = self.target_releaseproject unless self.target_releaseproject.blank?
        action.target attributes
      elsif self.action_type == :add_role || self.action_type == :set_bugowner
        attributes = {}
        attributes[:project] = self.target_project unless self.target_project.blank?
        attributes[:package] = self.target_package unless self.target_package.blank?
        action.target attributes
        if self.person_name
          if self.action_type == :add_role
            action.person :name => self.person_name, :role => self.role
          else
            action.person :name => self.person_name
          end
        end
        if self.group_name
          action.group :name => self.group_name, :role => self.role
        end
      elsif self.action_type == :delete
        attributes = {}
        attributes[:project] = self.target_project unless self.target_project.blank?
        attributes[:package] = self.target_package unless self.target_package.blank?
        action.target attributes
      else
        raise "Not supported action type #{self.action_type}"
      end
      if self.sourceupdate || self.updatelink
        action.options do
          action.sourceupdate self.sourceupdate if self.sourceupdate
          action.updatelink "true" if self.updatelink
        end
      end
      bs_request_action_accept_info.render_xml(builder) unless bs_request_action_accept_info.nil?
    end
  end
  
  def set_acceptinfo(ai)
    self.bs_request_action_accept_info = BsRequestActionAcceptInfo.create(ai)
  end
end
