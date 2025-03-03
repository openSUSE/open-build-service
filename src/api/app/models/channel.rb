class Channel < ApplicationRecord
  include ModelHelper

  belongs_to :package, touch: true
  has_many :channel_targets, dependent: :destroy
  has_many :channel_binary_lists, dependent: :destroy

  def self.verify_xml!(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a?(String)
    xmlhash.elements('target') do |p|
      prj = Project.get_by_name(p['project'])
      raise UnknownRepository, "Repository does not exist #{prj.name}/#{p['repository']}" unless prj.repositories.find_by_name(p['repository'])
    end
    xmlhash.elements('binaries').each do |p|
      project = p['project']
      if project.present?
        prj = Project.get_by_name(p['project'])
        prj.repositories.find_by_name!(p['repository']) if p['repository']
      end
      Architecture.find_by_name!(p['arch']) if p['arch']
      p.elements('binary') do |b|
        Architecture.find_by_name!(b['arch']) if b['arch']
        project = b['project']
        if project
          prj = Project.get_by_name(project)
          if b['package']
            pkg = prj.find_package(b['package'].gsub(/:.*$/, ''))
            raise UnknownPackage, "Package does not exist #{prj.name}/#{p['package']}" unless pkg
          end
          raise UnknownRepository, "Repository does not exist #{prj.name}/#{b['repository']}" if b['repository'] && !prj.repositories.find_by_name(b['repository'])
        end
      end
    end
  end

  def name
    project_name = package.project.name.tr(':', '_')

    "#{package.name}.#{project_name}"
  end

  def update_from_xml(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a?(String)

    self.disabled = xmlhash.key?('disabled')
    _update_from_xml_targets(xmlhash)
    _update_from_xml_binary_lists(xmlhash)

    if package.project.maintenance_incident? || package.link?
      # we skip binaries in incidents and when they are just a branch
      # we do not need the data since it is not the origin definition
      save
      return
    end

    # sync binaries for all lists
    channel_binary_lists.each do |cbl|
      hasharray = []
      # search the right xml binaries group for this cbl
      xmlhash.elements('binaries') do |b|
        next if cbl.project      && b['project'] != cbl.project.name
        next if cbl.repository   && b['repository'] != cbl.repository.name
        next if cbl.architecture && b['arch'] != cbl.architecture.name
        next if cbl.project.nil?      && b['project']
        next if cbl.repository.nil?   && b['repository']
        next if cbl.architecture.nil? && b['arch']

        hasharray << b['binary']
      end
      hasharray.flatten!
      # no match? either not created or searched in the right way
      raise "Unable to find binary list #{cbl.project.name} #{cbl.repository.name} #{cbl.architecture.name}" if hasharray.empty?

      # update...
      _update_from_xml_binaries(cbl, hasharray)
    end
    save
  end

  def branch_channel_package_into_project(project, comment = nil)
    # create a package container
    target_package = Package.new(name: name, title: package.title, description: package.description)
    project.packages << target_package
    target_package.store(comment: comment)

    # branch sources
    target_package.branch_from(package.project.name, package.name, comment: comment)
    target_package.sources_changed(wait_for_update: true)

    target_package
  end

  def active?
    return false if disabled

    # no targets defined, the project has some
    return true if channel_targets.empty?

    channel_targets.where(disabled: false).present?
  end

  def add_channel_repos_to_project(target_package, mode = nil)
    if channel_targets.empty?
      # not defined in channel, so take all from project
      target_package.project.branch_to_repositories_from(package.project, package, extend_names: true)
      return
    end

    # defined in channel
    channel_targets.each do |ct|
      next if mode == :skip_disabled && ct.disabled

      repo_name = ct.repository.extended_name
      next unless mode == :enable_all || !ct.disabled

      # add repositories
      if !package.project.repositories.find_by_name(repo_name) && !target_package.project.repositories.exists?(name: repo_name)
        target_repo = target_package.project.repositories.create(name: repo_name)
        target_package.project.add_repository_targets(target_repo, ct.repository, [ct.repository])
      end
      # enable package
      target_package.enable_for_repository(repo_name)
    end
  end

  private

  def _update_from_xml_binaries(cbl, xmlhash)
    hasharray = []
    xmlhash.each do |b|
      arch = nil
      arch = Architecture.find_by_name!(b['arch']) if b['arch']
      hash = { name: b['name'], binaryarch: b['binaryarch'], supportstatus: b['supportstatus'],
               superseded_by: b['superseded_by'], project: nil, architecture: arch, repository: nil }
      hash[:package] = b['package'].blank? ? nil : b['package'].gsub(/:.*$/, '')
      if b['project']
        hash[:project] = Project.get_by_name(b['project'])
        hash[:repository] = hash[:project].repositories.find_by_name(b['repository']) if b['repository']
      end
      hasharray << hash
    end
    sync_hash_with_model(ChannelBinary, cbl.channel_binaries, hasharray)
  end

  def _update_from_xml_binary_lists(xmlhash)
    # sync binary lists
    hasharray = []
    xmlhash.elements('binaries').each do |p|
      repository = nil
      project = p['project']
      if project.present?
        project = Project.find_by_name(project)
        next unless project

        repository = project.repositories.find_by_name(p['repository']) if p['repository']
        next unless repository
      end
      arch = nil
      arch = Architecture.find_by_name!(p['arch']) if p['arch']
      hasharray << { project: project, architecture: arch,
                     repository: repository }
    end
    sync_hash_with_model(ChannelBinaryList, channel_binary_lists, hasharray)
  end

  def _update_from_xml_targets(xmlhash)
    # sync channel targets
    hasharray = []
    xmlhash.elements('target').each do |p|
      prj = Project.find_by_name(p['project'])
      next unless prj

      r = prj.repositories.find_by_name(p['repository'])
      next unless r

      hasharray << { project: r.project,
                     repository: r, id_template: p['id_template'],
                     requires_issue: p['requires_issue'],
                     disabled: p.key?('disabled') }
    end
    sync_hash_with_model(ChannelTarget, channel_targets, hasharray)
  end
end

# == Schema Information
#
# Table name: channels
#
#  id         :integer          not null, primary key
#  disabled   :boolean
#  package_id :integer          not null, indexed
#
# Indexes
#
#  index_unique  (package_id) UNIQUE
#
# Foreign Keys
#
#  channels_ibfk_1  (package_id => packages.id)
#
