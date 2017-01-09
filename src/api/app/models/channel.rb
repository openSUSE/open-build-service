class Channel < ApplicationRecord
  include ModelHelper

  belongs_to :package, foreign_key: :package_id
  has_many :channel_targets, dependent: :destroy
  has_many :channel_binary_lists, dependent: :destroy

  def self.verify_xml!(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a? String
    xmlhash.elements('target') { |p|
      prj = Project.get_by_name(p['project'])
      unless prj.repositories.find_by_name(p['repository'])
        raise UnknownRepository.new "Repository does not exist #{prj.name}/#{p['repository']}"
      end
    }
    xmlhash.elements('binaries').each { |p|
      project = p['project']
      unless project.blank?
        prj = Project.get_by_name( p['project'] )
        prj.repositories.find_by_name!( p['repository'] ) if p['repository']
      end
      Architecture.find_by_name!( p['arch'] ) if p['arch']
      p.elements('binary') { |b|
        Architecture.find_by_name!( b['arch'] ) if b['arch']
        project = b['project']
        if project
          prj = Project.get_by_name( project )
          if b['package']
            pkg = prj.find_package(b['package'] )
            raise UnknownPackage.new "Package does not exist #{prj.name}/#{p['package']}" unless pkg
          end
          if b['repository'] && !prj.repositories.find_by_name(b['repository'])
            raise UnknownRepository.new "Repository does not exist #{prj.name}/#{b['repository']}"
          end
        end
      }
    }
  end

  def name
    project_name = package.project.name.tr(":", "_")

    "#{package.name}.#{project_name}"
  end

  def _update_from_xml_targets(xmlhash)
    # sync channel targets
    hasharray = []
    xmlhash.elements('target').each { |p|
      prj = Project.find_by_name(p['project'])
      next unless prj
      r = prj.repositories.find_by_name(p['repository'])
      next unless r
      hasharray << { project: r.project,
                     repository: r, id_template: p['id_template'],
                     requires_issue: p['requires_issue'],
                     disabled: (p.has_key? 'disabled') }
    }
    sync_hash_with_model(ChannelTarget, channel_targets, hasharray)
  end

  def _update_from_xml_binary_lists(xmlhash)
    # sync binary lists
    hasharray = []
    xmlhash.elements('binaries').each { |p|
      repository = nil
      project = p['project']
      unless project.blank?
        project = Project.find_by_name(project)
        next unless project
        repository = project.repositories.find_by_name(p['repository']) if p['repository']
        next unless repository
      end
      arch = nil
      arch = Architecture.find_by_name!(p['arch']) if p['arch']
      hasharray << { project: project, architecture: arch,
                     repository: repository }
    }
    sync_hash_with_model(ChannelBinaryList, channel_binary_lists, hasharray)
  end

  def _update_from_xml_binaries(cbl, xmlhash)
    hasharray = []
    xmlhash.each do |b|
      arch = nil
      arch = Architecture.find_by_name!(b['arch']) if b['arch']
      hash = { name: b['name'], binaryarch: b['binaryarch'], supportstatus: b['supportstatus'],
               project: nil, architecture: arch,
               package: b['package'], repository: nil }
      if b['project']
        hash[:project] = Project.get_by_name(b['project'])
        hash[:repository] = hash[:project].repositories.find_by_name(b['repository']) if b['repository']
      end
      hasharray << hash
    end
    sync_hash_with_model(ChannelBinary, cbl.channel_binaries, hasharray)
  end

  def update_from_xml(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a? String

    _update_from_xml_targets(xmlhash)
    _update_from_xml_binary_lists(xmlhash)

    if package.project.is_maintenance_incident? || package.is_link?
      # we skip binaries in incidents and when they are just a branch
      # we do not need the data since it is not the origin definition
      save
      return
    end

    # sync binaries for all lists
    channel_binary_lists.each { |cbl|
      hasharray = Array.new
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
      raise "Unable to find binary list #{cbl.project.name} #{cbl.repository.name} #{cbl.architecture.name}" if hasharray.size < 1
      # update...
      _update_from_xml_binaries(cbl, hasharray)
    }
    save
  end

  def branch_channel_package_into_project(project, comment = nil)
    cp = package

    # create a package container
    tpkg = Package.new(name: name, title: cp.title, description: cp.description)
    project.packages << tpkg
    tpkg.store({comment: comment})

    # branch sources
    tpkg.branch_from(cp.project.name, cp.name, nil, nil, comment)
    tpkg.sources_changed(wait_for_update: true)

    tpkg
  end

  def is_active?
    # no targets defined, the project has some
    return true if channel_targets.size.zero?

    channel_targets.where(disabled: false).size > 0
  end

  def add_channel_repos_to_project(tpkg, mode = nil)
    cp = package
    if channel_targets.empty?
      # not defined in channel, so take all from project
      tpkg.project.branch_to_repositories_from(cp.project, cp, {extend_names: true})
      return
    end

    # defined in channel
    channel_targets.each do |ct|
      next if mode == :skip_disabled && ct.disabled
      repo_name = ct.repository.extended_name
      next unless mode == :enable_all || !ct.disabled
      # add repositories
      unless cp.project.repositories.find_by_name(repo_name)
        tpkg.project.add_repository_with_targets(repo_name, ct.repository, [ct.repository])
      end
      # enable package
      tpkg.enable_for_repository repo_name
    end
  end
end
