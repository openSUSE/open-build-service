# -*- coding: utf-8 -*-
require 'api_exception'

class BsRequestAction < ActiveRecord::Base

  include ParsePackageDiff

  # we want the XML attribute in the database
  #  self.store_full_sti_class = false

  class DiffError < APIException
    # a diff error can have many reasons, but most likely something within us
    setup 404
  end

  belongs_to :bs_request
  has_one :bs_request_action_accept_info, :dependent => :delete

  VALID_SOURCEUPDATE_OPTIONS = ["update", "noupdate", "cleanup"]
  validates_inclusion_of :sourceupdate, :in => VALID_SOURCEUPDATE_OPTIONS, :allow_nil => true

  validate :check_sanity

  def check_sanity
    if [:submit, :maintenance_incident, :maintenance_release, :change_devel].include? action_type
      errors.add(:source_project, "should not be empty for #{action_type} requests") if source_project.blank?
      if !is_maintenance_incident?
        errors.add(:source_package, "should not be empty for #{action_type} requests") if source_package.blank?
      end
      errors.add(:target_project, "should not be empty for #{action_type} requests") if target_project.blank?
      if source_package == target_package and source_project == target_project
        if self.sourceupdate or self.updatelink
          errors.add(:target_package, "No source changes are allowed, if source and target is identical")
        end
      end
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

  # convenience functions to check types
  def is_maintenance_release?
    false
  end

  def is_maintenance_incident?
    false
  end

  def matches_package?(source_or_target, pkg)
    (self.send("#{source_or_target}_project") == pkg.project.name) and
        (self.send("#{source_or_target}_package") == pkg.name)
  end

  def self.type_to_class_name(type_name)
    case type_name
      when :submit then
        BsRequestActionSubmit
      when :delete then
        BsRequestActionDelete
      when :change_devel then
        BsRequestActionChangeDevel
      when :add_role then
        BsRequestActionAddRole
      when :set_bugowner then
        BsRequestActionSetBugowner
      when :maintenance_incident then
        BsRequestActionMaintenanceIncident
      when :maintenance_release then
        BsRequestActionMaintenanceRelease
      when :group then
        BsRequestActionGroup
      else
        nil
    end
  end

  def self.find_sti_class(type_name)
    return super if type_name.nil?
    type_to_class_name(type_name.to_sym) || super
  end

  def self.new_from_xml_hash(hash)
    classname = type_to_class_name(hash.delete("type").to_sym)
    if classname
      a = classname.new
    else
      raise ArgumentError, "unknown type"
    end

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
      self.source_rev = source.delete("rev")

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

  def xml_package_attributes(source_or_target)
    attributes = {}
    value = self.send "#{source_or_target}_project"
    attributes[:project] = value unless value.blank?
    value = self.send "#{source_or_target}_package"
    attributes[:package] = value unless value.blank?
    attributes
  end

  def render_xml_source(node)
    attributes = xml_package_attributes('source')
    attributes[:rev] = self.source_rev unless self.source_rev.blank?
    node.source attributes
  end

  def render_xml_target(node)
    attributes = xml_package_attributes('target')
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
      ret[:person] = nil
      ret[:role] = nil
    elsif self.action_type == :change_devel
      ret[:sourceproject] = self.source_project
      ret[:sourcepackage] = self.source_package
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package || self.source_package
      ret[:sourcerevision] = nil
      ret[:person] = nil
      ret[:role] = nil
    elsif self.action_type == :add_role
      ret[:targetproject] = self.target_project
      ret[:targetpackage] = self.target_package
      ret[:sourceproject] = nil
      ret[:sourcepackage] = nil
      ret[:sourcerevision] = nil
      ret[:person] = self.person_name
      ret[:role] = self.role
    elsif self.action_type == :delete
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
    return ''
  end

  def webui_infos
    begin
      sd = self.sourcediff(view: 'xml', withissues: true)
    rescue DiffError, Project::UnknownObjectError, Package::UnknownObjectError => e
      return [{error: e.message}]
    end
    diff = sorted_filenames_from_sourcediff(sd)
    if diff[0].empty?
      nil
    else
      diff
    end
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
      if self.is_maintenance_release?
        # use orignal/stripped name and also GA projects for maintenance packages.
        # But do not follow project links, if we have a branch target project, like in Evergreen case
        if tprj.find_attribute("OBS", "BranchTarget")
          tpkg = tprj.packages.find_by_name self.target_package.gsub(/\.[^\.]*$/, '')
        else
          tpkg = tprj.find_package self.target_package.gsub(/\.[^\.]*$/, '')
        end
      elsif [:set_bugowner, :add_role, :change_devel, :delete].include? self.action_type
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
        reviews.push(tpkg.develpackage)
      end

      if !self.is_maintenance_release?
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
              reviews.push(spkg)
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
              reviews.push(sprj)
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

    reviewer_id = Role.rolecache["reviewer"].id

    # check for reviewers in a package first
    if obj.class == Project
      obj.relationships.users.where(role_id: reviewer_id).pluck(:user_id).each do |r|
        reviewers << User.find(r)
      end
      obj.relationships.groups.where(role_id: reviewer_id).pluck(:group_id).each do |r|
        reviewers << Group.find(r)
      end
    elsif obj.class == Package
      obj.relationships.users.where(role_id: reviewer_id).pluck(:user_id).each do |r|
        reviewers << User.find(r)
      end
      obj.relationships.groups.where(role_id: reviewer_id).pluck(:group_id).each do |r|
        reviewers << Group.find(r)
      end
      reviewers += find_reviewers(obj.project)
    end

    return reviewers
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

  class ExpandError < APIException;
    setup "expand_error"
  end
  class SourceChanged < APIException;
  end

  class ReleaseTargetNoPermission < APIException
    setup 403
  end

  class NotExistingTarget < APIException;
  end
  class RepositoryMissing < APIException;
  end

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

    if [:submit, :change_devel, :maintenance_release, :maintenance_incident].include? self.action_type
      source_package = nil
      if ["declined", "revoked", "superseded"].include? opts[:newstate]
        # relaxed access checks for getting rid of request
        source_project = Project.find_by_name(self.source_project)
      else
        # full read access checks
        source_project = Project.get_by_name(self.source_project)
        target_project = Project.get_by_name(self.target_project)
        if self.action_type == :change_devel and self.target_package.nil?
          raise TargetPackageMissing.new "Target package is missing in request #{self.bs_request.id} (type #{self.action_type})"
        end
        if self.source_package or self.action_type == :change_devel
          source_package = Package.get_by_project_and_name self.source_project, self.source_package
        end
        # require a local source package
        if [:change_devel].include? self.action_type
          unless source_package
            raise SourceMissing.new "Local source package is missing for request #{self.bs_request.id} (type #{self.action_type})"
          end
        end
        # accept also a remote source package
        if source_package.nil? and [:submit].include? self.action_type
          unless Package.exists_by_project_and_name(source_project.name, self.source_package,
                                                    follow_project_links: true, allow_remote_packages: true)
            raise SourceMissing.new "Source package is missing for request #{self.bs_request.id} (type #{self.action_type})"
          end
        end
        # maintenance incident target permission checks
        if is_maintenance_incident?
          if opts[:cmd] == "setincident"
            if target_project.is_maintenance_incident?
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
            unless ["maintenance", "maintenance_incident"].include? target_project.project_type.to_s
              raise TargetNotMaintenance.new "The target project is not of type maintenance or incident but #{target_project.project_type}"
            end
          end
        end
        # validate that specified sources do not have conflicts on accepting request
        if [:submit, :maintenance_incident].include? self.action_type and opts[:cmd] == "changestate" and opts[:newstate] == "accepted"
          url = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}?expand=1"
          url << "&rev=#{CGI.escape(self.source_rev)}" if self.source_rev
          begin
            c = ActiveXML.transport.direct_http(url)
          rescue ActiveXML::Transport::Error
            raise ExpandError.new "The source of package #{self.source_project}/#{self.source_package}#{self.source_rev ? " for revision #{self.source_rev}" : ''} is broken"
          end
        end
        # maintenance_release accept check
        if [:maintenance_release].include? self.action_type and opts[:cmd] == "changestate" and opts[:newstate] == "accepted"
          # compare with current sources
          if self.source_rev
            # FIXME2.4 we have a directory model
            url = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}?expand=1"
            c = ActiveXML.transport.direct_http(url)
            data = REXML::Document.new(c)
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
        elsif [:submit, :change_devel].include? self.action_type
          # fallback for old requests, new created ones get this one added in any case.
          target_package = target_project.packages.find_by_name(self.source_package)
        end
      end

    elsif [:delete, :add_role, :set_bugowner].include? self.action_type
      if self.target_package
        target_package = target_project.packages.find_by_name(self.target_package) if target_project
      end
      if opts[:newstate] == "accepted"
        # target must exist
        if self.target_package
          unless target_package
            raise NotExistingTarget.new "Unable to process package #{self.target_project}/#{self.target_package}; it does not exist."
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
    if (source_package and User.current.can_modify_package?(source_package, true)) or
        (not source_package and source_project and User.current.can_modify_project?(source_project, true))
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
      if target_project and User.current.can_create_package_in?(target_project, true)
        write_permission_in_target = true
      end
      if target_project and User.current.can_create_package_in?(target_project)
        write_permission_in_this_action = true
      end
    end

    # abort immediatly if we want to write and can't
    if opts[:cmd] == "changestate" and ["accepted"].include? opts[:newstate] and not write_permission_in_this_action
      msg = ""
      msg = "No permission to modify target of request #{self.bs_request.id} (type #{self.action_type}): project #{self.target_project}" unless self.bs_request.new_record?
      msg += ", package #{self.target_package}" if self.target_package
      raise RequestNoPermission.new msg
    end

    return [write_permission_in_source, write_permission_in_target]
  end

  def get_releaseproject(pkg, tprj)
    # only needed for maintenance incidents
    nil
  end

  def execute_accept(opts)
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

  class BuildNotFinished < APIException
  end

  class UnknownTargetPackage < APIException
  end

  class WrongLinkedPackageSource < APIException
  end

  class MissingPatchinfo < APIException
  end

  class MissingAction < APIException
    setup 400, "The request contains no actions. Submit requests without source changes may have skipped!"
  end

  def create_expand_package(packages, opts = {})
    newactions = Array.new
    incident_suffix = ""
    if self.is_maintenance_release?
      # The maintenance ID is always the sub project name of the maintenance project
      incident_suffix = "." + self.source_project.gsub(/.*:/, "")
    end

    found_patchinfo = false
    newPackages = Array.new
    newTargets = Array.new
    logger.debug "expand package #{packages.inspect}"

    packages.each do |pkg|
      # find target via linkinfo or submit to all.
      # FIXME: this is currently handling local project links for packages with multiple spec files.
      #        This can be removed when we handle this as shadow packages in the backend.
      tprj = pkg.project.name
      tpkg = ltpkg = pkg.name
      rev = self.source_rev
      data = nil
      missing_ok_link=false
      suffix = ""
      while tprj == pkg.project.name
        # FIXME2.4 we have a Directory model!
        data = REXML::Document.new(Suse::Backend.get("/source/#{URI.escape(tprj)}/#{URI.escape(ltpkg)}").body)
        e = data.elements["directory/linkinfo"]
        if e
          suffix = ltpkg.gsub(/^#{e.attributes["package"]}/, '')
          ltpkg = e.attributes["package"]
          tprj = e.attributes["project"]
          missing_ok_link=true if e.attributes["missingok"]
        else
          tprj = nil
        end
      end
      tpkg = tpkg.gsub(/#{suffix}$/, '') # strip distro specific extension

      # maintenance incidents need a releasetarget
      releaseproject = self.get_releaseproject(pkg, tprj)

      # do not allow release requests without binaries
      if self.is_maintenance_release? and data and !opts[:ignore_build_state]
        entries = data.get_elements("directory/entry")
        entries.each do |entry|
          next unless entry.attributes["name"] == "_patchinfo"
          # check for build state and binaries
          state = REXML::Document.new(Suse::Backend.get("/build/#{URI.escape(pkg.project.name)}/_result").body)
          repos = state.get_elements("/resultlist/result[@project='#{pkg.project.name}'')]")
          unless repos
            raise BuildNotFinished.new "The project'#{pkg.project.name}' has no building repositories"
          end
          repos.each do |repo|
            unless ["finished", "publishing", "published", "unpublished"].include? repo.attributes['state']
              raise BuildNotFinished.new "The repository '#{pkg.project.name}' / '#{repo.attributes['repository']}' / #{repo.attributes['arch']}"
            end
          end
          pkg.project.repositories.each do |repo|
            firstarch=repo.architectures.first if repo
            if firstarch
              # skip excluded patchinfos
              status = state.get_elements("/resultlist/result[@repository='#{repo.name}' and @arch='#{firstarch.name}']").first
              unless status and s=status.get_elements("status[@package='#{pkg.name}']").first and s.attributes['code'] == "excluded"
                binaries = REXML::Document.new(Suse::Backend.get("/build/#{URI.escape(pkg.project.name)}/#{URI.escape(repo.name)}/#{URI.escape(firstarch.name)}/#{URI.escape(pkg.name)}").body)
                l = binaries.get_elements('binarylist/binary')
                if l and l.count > 0
                  found_patchinfo = true
                else
                  raise BuildNotFinished.new "patchinfo #{pkg.name} is not yet build for repository '#{repo.name}'"
                end
              end
            end
          end
        end
      end
      # Will this be a new package ?
      unless missing_ok_link
        unless e and Package.exists_by_project_and_name(tprj, tpkg, follow_project_links: true, allow_remote_packages: false)
          if self.is_maintenance_release?
            newPackages << pkg
            pkg.project.repositories.includes(:release_targets).each do |repo|
              repo.release_targets.each do |rt|
                newTargets << rt.target_repository.project.name
              end
            end
            next
          elsif !is_maintenance_incident?
            raise UnknownTargetPackage.new "target package does not exist"
          end
        end
      end
      # is this package source going to a project which is specified as release target ?
      if self.is_maintenance_release?
        found = nil
        pkg.project.repositories.includes(:release_targets).each do |repo|
          repo.release_targets.each do |rt|
            if rt.target_repository.project.name == tprj
              found = 1
            end
          end
        end
        unless found
          raise WrongLinkedPackageSource.new "According to the source link of package #{pkg.project.name}/#{pkg.name} it would go to project #{tprj} which is not specified as release target."
        end
      end

      newAction = self.dup
      newAction.source_package = pkg.name
      if self.is_maintenance_incident?
        newTargets << tprj
        newAction.target_releaseproject = releaseproject.name if releaseproject
      elsif self.is_maintenance_release? and pkg.is_of_kind? 'channel'
        newAction.action_type = :submit
        newAction.target_project = tprj
        newAction.target_package = tpkg
      else
        newTargets << tprj
        newAction.target_project = tprj
        newAction.target_package = tpkg + incident_suffix
      end
      newAction.source_rev = rev if rev
      # check if the source contains really a diff or we can skip the entire action
      if newAction.action_type == :submit and newAction.sourcediff.blank?
        # submit contains no diff, drop it again
        newAction.destroy
      else
        newactions << newAction
      end
    end
    if self.is_maintenance_release? and !found_patchinfo and !opts[:ignore_build_state]
      raise MissingPatchinfo.new 'maintenance release request without patchinfo would release no binaries'
    end

    # new packages (eg patchinfos) go to all target projects by default in maintenance requests
    newTargets.uniq!
    newPackages.each do |pkg|
      releaseTargets=nil
      if pkg.is_of_kind? 'patchinfo'
        releaseTargets = Patchinfo.new.fetch_release_targets(pkg)
      end
      newTargets.each do |p|
        unless releaseTargets.blank?
          found=false
          releaseTargets.each do |rt|
            if rt['project'] == p
              found=true
              break
            end
          end
          next unless found
        end
        newAction = self.dup
        newAction.source_package = pkg.name
        unless self.is_maintenance_incident?
          newAction.target_project = p
          newAction.target_package = pkg.name + incident_suffix
        end
        newactions << newAction
      end
    end

    raise MissingAction.new if newactions.empty?
    return newactions
  end

  class UnknownPackage < APIException
    setup 404, "No target package specified"
  end

  class IncidentHasNoMaintenanceProject < APIException
  end

  class NotSupported < APIException
  end

  class SubmitRequestRejected < APIException
  end

  class RequestRejected < APIException
    setup 403
  end

  class UnknownProject < APIException
    setup 404
  end

  class UnknownRole < APIException
    setup 404
  end

  class IllegalRequest < APIException
  end

  def check_action_permission!
    # find objects if specified or report error
    role=nil
    sprj=nil
    spkg=nil
    tprj=nil
    tpkg=nil
    if self.person_name
      # validate user object
      User.get_by_login(self.person_name)
    end
    if self.group_name
      # validate group object
      Group.get_by_title(self.group_name)
    end
    if self.role
      # validate role object
      role = Role.get_by_title(self.role)
    end
    if self.source_project
      sprj = Project.get_by_name self.source_project
      unless sprj
        raise UnknownProject.new "Unknown source project #{self.source_project}"
      end
      unless sprj.class == Project
        raise NotSupported.new "Source project #{self.source_project} is not a local project. This is not supported yet."
      end
      if self.source_package
        spkg = Package.get_by_project_and_name(self.source_project, self.source_package, use_source: true, follow_project_links: true)
      end
    end

    if self.target_project
      tprj = Project.get_by_name self.target_project
      if tprj.is_a? Project
        if tprj.project_type.to_sym == :maintenance_release and self.action_type == :submit
          raise SubmitRequestRejected.new "The target project #{self.target_project} is a maintenance release project, a submit self is not possible, please use the maintenance workflow instead."
        end
        if a = tprj.find_attribute("OBS", "RejectRequests") and a.values.first
          if a.values.length < 2 or a.values.find_by_value(self.action_type)
            raise RequestRejected.new "The target project #{self.target_project} is not accepting requests because: #{a.values.first.value.to_s}"
          end
        end
      end
      if self.target_package
        if Package.exists_by_project_and_name(self.target_project, self.target_package) or [:delete, :change_devel, :add_role, :set_bugowner].include? self.action_type
          tpkg = Package.get_by_project_and_name self.target_project, self.target_package
        end

        if tpkg && (a = tpkg.find_attribute("OBS", "RejectRequests") and a.values.first)
          if a.values.length < 2 or a.values.find_by_value(self.action_type)
            raise RequestRejected.new "The target package #{self.target_project} / #{self.target_package} is not accepting requests because: #{a.values.first.value.to_s}"
          end
        end
      end
    end

    # Type specific checks
    if self.action_type == :delete or self.action_type == :add_role or self.action_type == :set_bugowner
      #check existence of target
      unless tprj
        raise UnknownProject.new "No target project specified"
      end
      if self.action_type == :add_role
        unless role
          raise UnknownRole.new "No role specified"
        end
      end
    elsif [:submit, :change_devel, :maintenance_release, :maintenance_incident].include?(self.action_type)
      #check existence of source
      unless sprj
        # no support for remote projects yet, it needs special support during accept as well
        raise UnknownProject.new "No target project specified"
      end

      if self.is_maintenance_incident?
        if self.target_package
          raise IllegalRequest.new 'Maintenance requests accept only projects as target'
        end
        raise 'We should have expanded a target_project' unless self.target_project
        # validate project type
        prj = Project.get_by_name(self.target_project)
        unless ['maintenance', 'maintenance_incident'].include? prj.project_type.to_s
          raise IncidentHasNoMaintenanceProject.new 'incident projects shall only create below maintenance projects'
        end
      end

      if self.is_maintenance_release?
        self.check_permissions!
      end

      # source update checks
      if [:submit, :maintenance_incident].include?(self.action_type)
        # cleanup implicit home branches. FIXME3.0: remove this, the clients should do this automatically meanwhile
        if self.sourceupdate.nil? and self.target_project
          if "home:#{User.current.login}:branches:#{self.target_project}" == self.source_project
            self.sourceupdate = 'cleanup'
          end
        end
      end
      # allow cleanup only, if no devel package reference
      if self.sourceupdate == 'cleanup' && spkg
        spkg.can_be_deleted?
      end

      if self.action_type == :change_devel
        unless tpkg
          raise UnknownPackage.new
        end
      end
    else
      self.check_permissions!
    end

  end

  class NoMaintenanceProject < APIException
  end

  class UnknownAttribute < APIException
    setup 404
  end

  def expand_targets(ignore_build_state)
    if self.is_maintenance_incident?
      # find maintenance project
      maintenanceProject = nil
      if self.target_project
        maintenanceProject = Project.get_by_name self.target_project
      else
        # hardcoded default. frontends can lookup themselfs a different target via attribute search
        at = AttribType.find_by_name("OBS:MaintenanceProject")
        unless at
          raise AttributeNotFound.new "Required OBS:Maintenance attribute not found, system not correctly deployed."
        end
        maintenanceProject = Project.find_by_attribute_type(at).first
        unless maintenanceProject
          raise UnknownProject.new "There is no project flagged as maintenance project on server and no target in request defined."
        end
        self.target_project = maintenanceProject.name
      end
      unless maintenanceProject.is_maintenance_incident? or maintenanceProject.is_maintenance?
        raise NoMaintenanceProject.new "Maintenance incident requests have to go to projects of type maintenance or maintenance_incident"
      end
    end

    # expand target_package
    if [:submit, :maintenance_release, :maintenance_incident].include?(self.action_type)
      return nil if self.target_package
      per_package_locking = false
      packages = Array.new
      if self.source_package
        packages << Package.get_by_project_and_name(self.source_project, self.source_package)
        per_package_locking = true
      else
        packages = Project.get_by_name(self.source_project).packages
      end

      return self.create_expand_package(packages, ignore_build_state: ignore_build_state), per_package_locking
    end

    return nil
  end

  def check_for_expand_errors!(add_revision)

    return unless [:submit, :maintenance_incident, :maintenance_release].include? self.action_type

    # validate that the sources are not broken
    begin
      pr = ""
      if self.source_rev
        pr = "&rev=#{CGI.escape(self.source_rev)}"
      end
      # FIXM2.4 we have a Directory model
      url = "/source/#{CGI.escape(self.source_project)}/#{CGI.escape(self.source_package)}?expand=1" + pr
      c = Suse::Backend.get(url).body
      if add_revision and !self.source_rev
        data = REXML::Document.new(c)
        self.source_rev = data.elements["directory"].attributes["srcmd5"]
      end
    rescue ActiveXML::Transport::Error
      raise ExpandError.new "The source of package #{self.source_project}/#{self.source_package}#{self.source_rev ? " for revision #{self.source_rev}" : ''} is broken"
    end
  end

  protected

  def self.get_package_diff(path, query)
    path += "?#{query.to_query}"
    begin
      return ActiveXML.transport.direct_http(URI(path), method: "POST", timeout: 10)
    rescue Timeout::Error
      raise DiffError.new("Timeout while diffing #{path}")
    rescue ActiveXML::Transport::Error => e
      raise DiffError.new("The diff call for #{path} failed: #{e.summary}")
    end
  end

end
