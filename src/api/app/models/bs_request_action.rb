# -*- coding: utf-8 -*-
require 'api_exception'

class BsRequestAction < ActiveRecord::Base

  # we want the XML attribute in the database
#  self.store_full_sti_class = false

  class DiffError < Exception; end

  belongs_to :bs_request
  has_one :bs_request_action_accept_info, :dependent => :delete

  VALID_SOURCEUPDATE_OPTIONS = ["update", "noupdate", "cleanup"]
  validates_inclusion_of :sourceupdate, :in => VALID_SOURCEUPDATE_OPTIONS, :allow_nil => true

  validate :check_sanity

  def check_sanity
    if [:submit, :maintenance_incident, :maintenance_release, :change_devel].include? action_type
      errors.add(:source_project, "should not be empty for #{action_type} requests") if source_project.blank?
      if action_type != :maintenance_incident
        errors.add(:source_package, "should not be empty for #{action_type} requests") if source_package.blank?
      end
      errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
    end
    errors.add(:target_package, "is invalid package name") if target_package && !Package.valid_name?(target_package)
    errors.add(:source_package, "is invalid package name") if source_package && !Package.valid_name?(source_package)
    errors.add(:target_project, "is invalid project name") if target_project && !Project.valid_name?(target_project)
    errors.add(:source_project, "is invalid project name") if source_project && !Project.valid_name?(source_project)

    # TODO to be continued
  end

  def action_type
    self.class.sti_name
  end

  def self.find_sti_class(type_name)
    return super if type_name.nil?
    return case type_name.to_sym
           when :submit then BsRequestActionSubmit
           when :delete then BsRequestActionDelete
           when :change_devel then BsRequestActionChangeDevel
           when :add_role then BsRequestActionAddRole
           when :set_bugowner then BsRequestActionSetBugowner
           when :maintenance_incident then BsRequestActionMaintenanceIncident
           when :maintenance_release then BsRequestActionMaintenanceRelease
           when :group then BsRequestActionGroup
           else super
           end
  end

  def self.new_from_xml_hash(hash)
    a = case hash.delete("type").to_sym
        when :submit then BsRequestActionSubmit.new
        when :delete then BsRequestActionDelete.new
        when :change_devel then BsRequestActionChangeDevel.new
        when :add_role then BsRequestActionAddRole.new
        when :set_bugowner then BsRequestActionSetBugowner.new
        when :maintenance_incident then BsRequestActionMaintenanceIncident.new
        when :maintenance_release then BsRequestActionMaintenanceRelease.new
        when :group then BsRequestActionGroup.new
        else nil
        end
    
    raise ArgumentError, "unknown type" unless a

    # now remove things from hash
    a.store_from_xml(hash)

    raise ArgumentError, "too much information #{hash.inspect}" unless hash.blank?
    
    a
  end

  def store_from_xml(hash)
    source = hash.delete("source")
    if source
      self.source_package = source.delete("package")
      self.source_project = source.delete("project")
      self.source_rev     = source.delete("rev")

      raise ArgumentError, "too much information #{source.inspect}" unless source.blank?
    end

    target = hash.delete("target")
    if target
      self.target_package = target.delete("package")
      self.target_project = target.delete("project")
      self.target_releaseproject = target.delete("releaseproject")
      self.target_repository = target.delete("repository")

      raise ArgumentError, "too much information #{target.inspect}" unless target.blank?
    end

    ai = hash.delete("acceptinfo")
    if ai
      self.bs_request_action_accept_info = BsRequestActionAcceptInfo.new
      self.bs_request_action_accept_info.rev = ai.delete("rev")
      self.bs_request_action_accept_info.srcmd5 = ai.delete("srcmd5")
      self.bs_request_action_accept_info.osrcmd5 = ai.delete("osrcmd5")
      self.bs_request_action_accept_info.xsrcmd5 = ai.delete("xsrcmd5")
      self.bs_request_action_accept_info.oxsrcmd5 = ai.delete("oxsrcmd5")

      raise ArgumentError, "too much information #{ai.inspect}" unless ai.blank?
    end

    o = hash.delete("options")
    if o
      self.sourceupdate = o.delete("sourceupdate")
      # old form
      self.sourceupdate = "update" if self.sourceupdate == "1"
      # there is mess in old data ;(
      self.sourceupdate = nil unless VALID_SOURCEUPDATE_OPTIONS.include? self.sourceupdate

      self.updatelink = true if o.delete("updatelink") == "true"
      raise ArgumentError, "too much information #{s.inspect}" unless o.blank?
    end

    p = hash.delete("person")
    if p
      self.person_name = p.delete("name") { raise ArgumentError, "a person without name" }
      self.role = p.delete("role")
      raise ArgumentError, "too much information #{p.inspect}" unless p.blank?
    end

    g = hash.delete("group")
    if g 
      self.group_name = g.delete("name") { raise ArgumentError, "a group without name" }
      raise ArgumentError, "role already taken" if self.role
      self.role = g.delete("role")
      raise ArgumentError, "too much information #{g.inspect}" unless g.blank?
    end
  end

  def render_xml_source(node)
    attributes = {}
    attributes[:project] = self.source_project unless self.source_project.blank?
    attributes[:package] = self.source_package unless self.source_package.blank?
    attributes[:rev] = self.source_rev unless self.source_rev.blank?
    node.source attributes
  end

  def render_xml_target(node)
    attributes = {}
    attributes[:project] = self.target_project unless self.target_project.blank?
    attributes[:package] = self.target_package unless self.target_package.blank?
    attributes[:releaseproject] = self.target_releaseproject unless self.target_releaseproject.blank?
    node.target attributes
  end
  
  def render_xml_attributes(node)
   if [:submit, :maintenance_incident, :maintenance_release, :change_devel].include? self.action_type
     render_xml_source(node)
     render_xml_target(node)
   end
  end

  def render_xml(builder)
    builder.action :type => self.action_type do |action|
      render_xml_attributes(action)
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
        next if issue['state'] == 'deleted'
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
  
  class LackingMaintainership < APIException
    setup "lacking_maintainership", 403, "Creating a submit request action with options requires maintainership in source package"
  end

  def default_reviewers
    reviews = []
    return reviews unless self.target_project

    tprj = Project.get_by_name self.target_project
    tpkg = nil
    if self.target_package
      if self.action_type == :maintenance_release
        # use orignal/stripped name and also GA projects for maintenance packages.
        # But do not follow project links, if we have a branch target project, like in Evergreen case
        if tprj.find_attribute("OBS", "BranchTarget")
          tpkg = tprj.packages.find_by_name self.target_package.gsub(/\.[^\.]*$/, '')
        else
          tpkg = tprj.find_package self.target_package.gsub(/\.[^\.]*$/, '')
        end
      elsif [ :set_bugowner, :add_role, :change_devel, :delete ].include? self.action_type 
        # target must exists
        tpkg = tprj.packages.find_by_name! self.target_package
      else
        # just the direct affected target
        tpkg = tprj.packages.find_by_name self.target_package
      end
    else
      if self.source_package
        tpkg = tprj.packages.find_by_name self.source_package
      end
    end
    
    if self.source_project
      # if the user is not a maintainer if current devel package, the current maintainer gets added as reviewer of this request
      if self.action_type == :change_devel and tpkg.develpackage and not User.current.can_modify_package?(tpkg.develpackage, 1)
        reviews.push( tpkg.develpackage )
      end

      if self.action_type != :maintenance_release
        # Creating requests from packages where no maintainer right exists will enforce a maintainer review
        # to avoid that random people can submit versions without talking to the maintainers 
        # projects may skip this by setting OBS:ApprovedRequestSource attributes
        if self.source_package
          spkg = Package.find_by_project_and_name self.source_project, self.source_package
          if spkg and not User.current.can_modify_package? spkg
            if self.action_type == :submit
              if self.sourceupdate or self.updatelink
                # FIXME: completely misplaced in this function
                raise LackingMaintainership.new
              end
            end
            if  not spkg.project.find_attribute("OBS", "ApprovedRequestSource") and 
                not spkg.find_attribute("OBS", "ApprovedRequestSource")
              reviews.push( spkg )
            end
          end
        else
          sprj = Project.find_by_name self.source_project
          if sprj and not User.current.can_modify_project? sprj and not sprj.find_attribute("OBS", "ApprovedRequestSource")
            if self.action_type == :submit
              if self.sourceupdate or self.updatelink
                raise LackingMaintainership.new
              end
            end
            if  not sprj.find_attribute("OBS", "ApprovedRequestSource")
              reviews.push( sprj )
            end
          end
        end
      end
    end
    
    # find reviewers in target package
    if tpkg
      reviews += find_reviewers(tpkg)
    end
    # project reviewers get added additionaly - might be dups
    if tprj
      reviews += find_reviewers(tprj)
    end
    
    return reviews.uniq
  end

  #
  # find default reviewers of a project/package via role
  # 
  def find_reviewers(obj)
    # obj can be a project or package object
    reviewers = []
    
    # check for reviewers in a package first
    if obj.class == Project
      obj.project_user_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
        reviewers << User.find(r.bs_user_id)
      end
      obj.project_group_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
        reviewers << Group.find(r.bs_group_id)
      end
    elsif obj.class == Package
      obj.package_user_role_relationships.joins(:role).where("roles.title = 'reviewer'").select("bs_user_id").each do |r|
        reviewers << User.find(r.bs_user_id)
      end
      obj.package_group_role_relationships.where(role_id: Role.get_by_title("reviewer").id ).each do |r|
        reviewers << Group.find(r.bs_group_id)
      end
      reviewers += find_reviewers(obj.project)
    end
    
    return reviewers
  end

  class NotExistantTarget < APIException
    setup 'not_existing_target'
  end

  class TargetPackageMissing < APIException
    setup "post_request_no_permission", 403
  end

  class SourceMissing < APIException
    setup "unknown_package", 404
  end

  class TargetNotMaintenance < APIException
    setup 404
  end

  class ProjectLocked < APIException
    setup 403, "The target project is locked"
  end

  class ExpandError < APIException; end
  class SourceChanged < APIException; end

  class ReleaseTargetNoPermission < APIException
    setup 403
  end

  class NotExistingTarget < APIException; end
  class RepositoryMissing < APIException; end

  class RequestNoPermission < APIException
    setup "post_request_no_permission", 403
  end

  def request_changes_state(state, opts)
    # only groups care for now
  end
  
  # check if the action can change state - or throw an APIException if not
  def check_newstate!(opts)
    # all action types need a target project in any case for accept
    target_project = Project.find_by_name(self.target_project)
    target_package = source_package = nil
    if not target_project and opts[:newstate] == "accepted"
      raise NotExistingTarget.new "Unable to process project #{self.target_project}; it does not exist."
    end

    if [ :submit, :change_devel, :maintenance_release, :maintenance_incident ].include? self.action_type
      source_package = nil
      if [ "declined", "revoked", "superseded" ].include? opts[:newstate]
        # relaxed access checks for getting rid of request
        source_project = Project.find_by_name(self.source_project)
      else
        # full read access checks
        source_project = Project.get_by_name(self.source_project)
        target_project = Project.get_by_name(self.target_project)
        if self.action_type == :change_devel and self.target_package.nil?
          raise TargetPackageMissing.new "Target package is missing in request #{req.id} (type #{self.action_type})"
        end
        if self.source_package or self.action_type == :change_devel
          source_package = Package.get_by_project_and_name self.source_project, self.source_package
        end
        # require a local source package
        if [ :change_devel ].include? self.action_type
          unless source_package
            raise SourceMissing.new "Local source package is missing for request #{req.id} (type #{self.action_type})"
          end
        end
        # accept also a remote source package
        if source_package.nil? and [ :submit ].include? self.action_type
          unless Package.exists_by_project_and_name( source_project.name, self.source_package, 
                                                     follow_project_links: true, allow_remote_packages: true)
            raise SourceMissing.new "Source package is missing for request #{req.id} (type #{self.action_type})"
          end
        end
        # maintenance incident target permission checks
        if [ :maintenance_incident ].include? self.action_type
          if opts[:cmd] == "setincident"
            if target_project.project_type == "maintenance_incident"
              raise TargetNotMaintenance.new "The target project is already an incident, changing is not possible via set_incident"
            end
            unless target_project.project_type == "maintenance"
              raise TargetNotMaintenance.new "The target project is not of type maintenance but #{target_project.project_type}"
            end
            tip = Project.get_by_name(self.target_project + ":" + opts[:incident])
            if tip && tip.is_locked?
              raise ProjectLocked.new
            end
          else
            unless [ "maintenance", "maintenance_incident" ].include? target_project.project_type.to_s
              raise TargetNotMaintenance.new "The target project is not of type maintenance or incident but #{target_project.project_type}"
            end
          end
        end
        # validate that specified sources do not have conflicts on accepting request
        if [ :submit, :maintenance_incident ].include? self.action_type and opts[:cmd] == "changestate" and opts[:newstate] == "accepted"
          url = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}?expand=1"
          url << "&rev=#{CGI.escape(self.source_rev)}" if self.source_rev
          begin
            c = ActiveXML.transport.direct_http(url)
          rescue ActiveXML::Transport::Error
            raise ExpandError.new "The source of package #{self.source_project}/#{self.source_package}#{self.source_rev ? " for revision #{self.source_rev}":''} is broken"
          end
        end
        # maintenance_release accept check
        if [ :maintenance_release ].include? self.action_type and opts[:cmd] == "changestate" and opts[:newstate] == "accepted"
          # compare with current sources
          if self.source_rev
            # FIXME2.4 we have a directory model
            url = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}?expand=1"
            c = ActiveXML.transport.direct_http(url)
            data = REXML::Document.new( c )
            unless self.source_rev == data.elements["directory"].attributes["srcmd5"]
              raise SourceChanged.new "The current source revision in #{self.source_project}/#{self.source_package} are not on revision #{self.source_rev} anymore."
            end
          end
          
          # write access check in release targets
          source_project.repositories.each do |repo|
            repo.release_targets.each do |releasetarget|
              unless User.current.can_modify_project? releasetarget.target_repository.project
                raise ReleaseTargetNoPermission.new "Release target project #{releasetarget.target_repository.project.name} is not writable by you"
              end
            end
          end
        end
      end
      if target_project
        if self.target_package
          target_package = target_project.packages.find_by_name(self.target_package)
        elsif [ :submit, :change_devel ].include? self.action_type
          # fallback for old requests, new created ones get this one added in any case.
          target_package = target_project.packages.find_by_name(self.source_package)
        end
      end
      
    elsif [ :delete, :add_role, :set_bugowner ].include? self.action_type
      # target must exist
      if opts[:newstate] == "accepted"
        if self.target_package
          target_package = target_project.packages.find_by_name(self.target_package)
          unless target_package
            raise NotExistantTarget.new "Unable to process package #{self.target_project}/#{self.target_package}; it does not exist."
          end
          if self.action_type == :delete
            target_package.can_be_deleted?
          end
        else
          if self.action_type == :delete
            if self.target_repository
              r=Repository.find_by_project_and_repo_name(target_project.name, self.target_repository)
              unless r
                raise RepositoryMissing.new "The repository #{target_project} / #{self.target_repository} does not exist"
              end
            else
              # remove entire project
              target_project.can_be_deleted?
            end
          end
        end
      end
    else
      raise RequestNoPermission.new "Unknown request type #{opts[:newstate]} of request #{self.bs_request.id} (type #{self.action_type})"
    end
    
    # general source write permission check (for revoke)
    if ( source_package and User.current.can_modify_package?(source_package,true) ) or
        ( not source_package and source_project and User.current.can_modify_project?(source_project,true) )
      write_permission_in_source = true
    end
    
    # general write permission check on the target on accept
    write_permission_in_this_action = false
    if target_package 
      if User.current.can_modify_package? target_package
        write_permission_in_target = true
        write_permission_in_this_action = true
      end
    else
      if target_project and User.current.can_create_package_in?(target_project,true)
        write_permission_in_target = true
      end
      if target_project and User.current.can_create_package_in?(target_project)
        write_permission_in_this_action = true
      end
    end
    
    # abort immediatly if we want to write and can't
    if opts[:cmd] == "changestate" and [ "accepted" ].include? opts[:newstate] and not write_permission_in_this_action
      msg = "No permission to modify target of request #{self.bs_request.id} (type #{self.action_type}): project #{self.target_project}"
      msg += ", package #{self.target_package}" if self.target_package
      raise RequestNoPermission.new msg
    end
    
    return [write_permission_in_source, write_permission_in_target]
  end
  
  def get_releaseproject(pkg, tprj)
    # only needed for maintenance incidents
    nil
  end

  def execute_changestate(opts)
    raise "Needs to be reimplemented in subclass"
  end

  # after all actions are executed, the controller calls into every action a cleanup
  # the actions can "cache" in the opts their state to avoid duplicated work
  def per_request_cleanup(opts)
    # does nothing by default
  end

  # this is called per action once it's verified that all actions in a request are
  # permitted.
  def create_post_permissions_hook(opts)
    # does nothing by default
  end

  # general source cleanup, used in submit and maintenance_incident actions
  def source_cleanup
    # cleanup source project
    source_project = Project.find_by_name(self.source_project)
    delete_path = nil
    if source_project.packages.count == 1 or self.source_package.nil?
      # remove source project, if this is the only package and not the user's home project
      if source_project.name != "home:" + User.current.login
        source_project.destroy
        delete_path = "/source/#{self.source_project}"
      end
    else
      # just remove one package
      source_package = source_project.packages.find_by_name(self.source_package)
      source_package.destroy
      delete_path = "/source/#{self.source_project}/#{self.source_package}"
    end
    del_params = {
      :user => User.current.login,
      :requestid => self.bs_request.id,
      :comment => self.bs_request.description
    }
    delete_path << Suse::Backend.build_query_from_hash(del_params, [:user, :comment, :requestid])
    Suse::Backend.delete delete_path
  end
end
