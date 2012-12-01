# -*- coding: utf-8 -*-
class BsRequestAction < ActiveRecord::Base

  class DiffError < Exception; end

  belongs_to :bs_request
  has_one :bs_request_action_accept_info, :dependent => :delete

  validates_inclusion_of :action_type, :in => [:submit, :delete, :change_devel, :add_role, :set_bugowner, 
                                               :maintenance_incident, :maintenance_release]
  VALID_SOURCEUPDATE_OPTIONS = ["update", "noupdate", "cleanup"]
  validates_inclusion_of :sourceupdate, :in => VALID_SOURCEUPDATE_OPTIONS, :allow_nil => true

  attr_accessible :source_package, :source_project, :source_rev, :target_package, :target_releaseproject, :target_repository,
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
    if action_type == :delete
      errors.add(:source_project, "source can not be used in delete action") if source_project
      errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
      errors.add(:target_project, "must not target package and target repository") if target_repository and target_package
    end
    errors.add(:target_package, "is invalid package name") if target_package && !Package.valid_name?(target_package)
    errors.add(:source_package, "is invalid package name") if source_package && !Package.valid_name?(source_package)
    errors.add(:target_project, "is invalid project name") if target_project && !Project.valid_name?(target_project)
    errors.add(:source_project, "is invalid project name") if source_project && !Project.valid_name?(source_project)

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
      a.target_repository = target.delete("repository")

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
        attributes[:repository] = self.target_repository unless self.target_repository.blank?
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

  def notify_params(ret = {})
    ret[:type] = self.action_type.to_s
    if self.action_type == :submit
      ret[:sourceproject] = self.source_project
      ret[:sourcepackage] = self.source_package
      ret[:sourcerevision] = self.source_rev
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package
      ret[:deleteproject] = nil
      ret[:deletepackage] = nil
      ret[:person] = nil
      ret[:role] = nil
    elsif self.action_type == :change_devel
      ret[:sourceproject] = self.source_project
      ret[:sourcepackage] = self.source_package
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package || self.source_package
      ret[:deleteproject] = nil
      ret[:deletepackage] = nil
      ret[:sourcerevision] = nil
      ret[:person] = nil
      ret[:role] = nil
    elsif self.action_type == :add_role
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package
      ret[:sourceproject] = nil
      ret[:sourcepackage] = nil
      ret[:deleteproject] = nil
      ret[:deletepackage] = nil
      ret[:sourcerevision] = nil
      ret[:person] = self.person_name
      ret[:role] = self.role
    elsif self.action_type == :delete
      # FIXME3 this parameter is duplicating infos
      ret[:deleteproject] = self.target_project
      ret[:deletepackage] = self.target_package
      ret[:sourceproject] = nil
      ret[:sourcepackage] = nil
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package
      ret[:sourcerevision] = nil
      ret[:person] = nil
      ret[:role] = nil
    end
    return ret
  end

  def sourcediff(opts = {})
    action_diff = ''
    path = nil
    if [:submit, :maintenance_release, :maintenance_incident].include?(self.action_type)
      spkgs = []
      ai = self.bs_request_action_accept_info
      if ai # the old package can be gone
        spkgs << self.source_package
      else
        if self.source_package
          sp = Package.find_by_project_and_name( self.source_project, self.source_package )
          if sp
            sp.check_source_access!
            spkgs << sp.name
          end
        else
          prj = Project.find_by_name( self.source_project )
          prj.packages.each do |p|
            p.check_source_access!
            spkgs << p.name
          end if prj
        end
      end

      spkgs.each do |spkg|
        target_project = self.target_project
        target_package = self.target_package
        
        # the target is by default the _link target
        # maintenance_release creates new packages instance, but are changing the source only according to the link
        provided_in_other_action=false
        if !self.target_package or [ :maintenance_release, :maintenance_incident ].include? self.action_type
          data = Xmlhash.parse( ActiveXML.transport.direct_http(URI("/source/#{URI.escape(self.source_project)}/#{URI.escape(spkg)}") ) )
          e = data['linkinfo']
          if e
            target_project = e["project"]
            target_package = e["package"]
            if target_project == self.source_project
              # a local link, check if the real source change gets also transported in a seperate action
              self.bs_request.bs_request_actions.each do |a|
                if self.source_project == a.source_project and e["package"] == a.source_package and
                    self.target_project == a.target_project
                  provided_in_other_action=true
                end
              end
            end
          end
        end

        # maintenance incidents shall show the final result after release
        target_project = self.target_releaseproject if self.target_releaseproject

        # fallback name as last resort
        target_package ||= self.source_package

        ai = self.bs_request_action_accept_info
        if ai
          # OBS 2.1 adds acceptinfo on request accept
          path = "/source/%s/%s?cmd=diff" % [CGI.escape(target_project), CGI.escape(target_package)]
          if ai.xsrcmd5
            path += "&rev=" + ai.xsrcmd5
          else
            path += "&rev=" + ai.srcmd5
          end
          if ai.oxsrcmd5
            path += "&orev=" + ai.oxsrcmd5
          elsif ai.osrcmd5
            path += "&orev=" + ai.osrcmd5
          else
            # "md5sum" of empty package
            path += "&orev=0"
          end
        else
          # for requests not yet accepted or accepted with OBS 2.0 and before
          tpkg = linked_tpkg = nil
          if Package.exists_by_project_and_name( target_project, target_package, follow_project_links: false )
            tpkg = Package.get_by_project_and_name( target_project, target_package )
          elsif Package.exists_by_project_and_name( target_project, target_package, follow_project_links: true )
            tpkg = linked_tpkg = Package.get_by_project_and_name( target_project, target_package )
          else
            Project.get_by_name( target_project )
          end

          path = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(spkg)}?cmd=diff&filelimit=10000"
          unless provided_in_other_action
            # do show the same diff multiple times, so just diff unexpanded so we see possible link changes instead
            # also get sure that the request would not modify the link in the target
            unless self.updatelink
              path += "&expand=1"
            end
          end
          if tpkg
            path += "&oproject=#{CGI.escape(target_project)}&opackage=#{CGI.escape(target_package)}"
            path += "&rev=#{self.source_rev}" if self.source_rev
          else # No target package means diffing the source package against itself.
            if self.source_rev # Use source rev for diffing (if available)
              path += "&orev=0&rev=#{self.source_rev}"
            else # Otherwise generate diff for latest source package revision
	      # FIXME: move to Package model
              spkg_rev = Directory.find(project: self.source_project, package: spkg).rev
              path += "&orev=0&rev=#{spkg_rev}"
            end
          end
        end
        # run diff
        path += '&view=xml' if opts[:view] == 'xml' # Request unified diff in full XML view
        path += '&withissues=1' if opts[:withissues]
        begin
          action_diff += ActiveXML.transport.direct_http(URI(path), method: "POST", timeout: 10)
        rescue Timeout::Error
          raise DiffError.new("Timeout while diffing #{path}")
        rescue ActiveXML::Transport::Error => e
          raise DiffError.new("The diff call for #{path} failed: #{e.summary}")
        end
        path = nil # reset
      end
    elsif self.action_type == :delete
      if self.target_package
        path = "/source/#{CGI.escape(self.target_project)}/#{CGI.escape(self.target_package)}"
        path += "?cmd=diff&expand=1&filelimit=0&rev=0"
        path += '&view=xml' if opts[:view] == 'xml' # Request unified diff in full XML view
        begin
          action_diff += ActiveXML.transport.direct_http(URI(path), method: "POST", timeout: 10)
        rescue Timeout::Error
          raise DiffError.new("Timeout while diffing #{path}")
        rescue ActiveXML::Transport::Error => e
          raise DiffError.new("The diff call for #{path} failed: #{e.summary}")
        end
      elsif self.target_repository
        # no source diff 
      else
        raise DiffError.new("Project diff isn't implemented yet")
      end
    end
    return action_diff
  end

  # FIXME this is code duplicated in the webui for package diffs - this needs to move into the API to then
  # move into helpers
  def webui_infos
    begin
      sd = self.sourcediff(view: 'xml', withissues: true)
    rescue DiffError, Project::UnknownObjectError, Package::UnknownObjectError => e
      return [ { error: e.message } ]
    end
    return {} if sd.blank?
    # Sort files into categories by their ending and add all of them to a hash. We
    # will later use the sorted and concatenated categories as key index into the per action file hash.
    changes_file_keys, spec_file_keys, patch_file_keys, other_file_keys = [], [], [], []
    files_hash, issues_hash = {}, {}

    parsed_sourcediff = []

    sd = "<diffs>" + sd + "</diffs>"
    Xmlhash.parse(sd).elements('sourcediff').each do |sourcediff|

      sourcediff.get('files').elements('file') do |file|
        if file['new']
          filename = file['new']['name']
        else # in case of deleted files
          filename = file['old']['name']
        end
        if filename.include?('/')
          other_file_keys << filename
        else
          if filename.ends_with?('.spec')
            spec_file_keys << filename
          elsif filename.ends_with?('.changes')
            changes_file_keys << filename
          elsif filename.match(/.*.(patch|diff|dif)/)
            patch_file_keys << filename
          else
            other_file_keys << filename
          end
        end
        files_hash[filename] = file
      end
     
      sourcediff.get('issues').elements('issue') do |issue|
        next unless issue['name']
        i = Issue.find_by_name_and_tracker(issue['name'], issue['tracker'])
        issues_hash[issue['label']] = i.webui_infos if i
      end
      
      parsed_sourcediff << {
        'old' => sourcediff['old'],
        'new' => sourcediff['new'],
        'filenames' => changes_file_keys.sort + spec_file_keys.sort + patch_file_keys.sort + other_file_keys.sort,
        'files' => files_hash,
        'issues' => issues_hash
      }
    end
    return parsed_sourcediff
  end

end
