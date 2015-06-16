class Channel < ActiveRecord::Base

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
          if b['repository'] and not prj.repositories.find_by_name(b['repository'])
            raise UnknownRepository.new "Repository does not exist #{prj.name}/#{b['repository']}"
          end
        end
      }
    }
  end

  def name
    name = package.name
    name += "."
    name += package.project.name.gsub(/:/,'_')
    return name
  end

  def _update_from_xml_targets(xmlhash)
    # sync channel targets
    hasharray=[]
    xmlhash.elements('target').each { |p|
      prj = Project.find_by_name(p['project'])
      next unless prj
      r = prj.repositories.find_by_name(p['repository'])
      next unless r
      hasharray << { repository: r, id_template: p['id_template'],
                     disabled: (p.has_key? 'disabled') }
    }
    sync_hash_with_model(ChannelTarget, self.channel_targets, hasharray)
  end

  def _update_from_xml_binary_lists(xmlhash)
    # sync binary lists
    hasharray=[]
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
    sync_hash_with_model(ChannelBinaryList, self.channel_binary_lists, hasharray)
  end

  def _update_from_xml_binaries(cbl, xmlhash)
    hasharray=[]
    xmlhash.elements('binary') { |b|
      arch = nil
      arch = Architecture.find_by_name!(b['arch']) if b['arch']
      hash = { name: b['name'], binaryarch: b['binaryarch'], supportstatus: b['supportstatus'],
               project: nil, architecture: arch,
               package: b['package'], repository: nil
             }
      if b['project']
        hash[:project] = Project.get_by_name(b['project'])
        hash[:repository] = hash[:project].repositories.find_by_name(b['repository']) if b['repository']
      end
      hasharray << hash
    }
    sync_hash_with_model(ChannelBinary, cbl.channel_binaries, hasharray)
  end

  def update_from_xml(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a? String

    _update_from_xml_targets(xmlhash)
    _update_from_xml_binary_lists(xmlhash)

    if self.package.project.is_maintenance_incident?
      # we skip binaries in incidents because we do not need them
      save
      return
    end

    # sync binaries for all lists
    self.channel_binary_lists.each { |cbl|
      p = nil
      # search the right xml binaries group for this cbl
      xmlhash.elements('binaries') do |b|
        next if cbl.project      and b['project'] != cbl.project.name
        next if cbl.repository   and b['repository'] != cbl.repository.name
        next if cbl.architecture and b['arch'] != cbl.architecture.name
        next if cbl.project.nil?      and b['project']
        next if cbl.repository.nil?   and b['repository']
        next if cbl.architecture.nil? and b['arch']
        # match, but only once
        raise "Illegal double match of binary list" if p
        p=b
      end
      # no match? either not created or searched in the right way
      raise "Unable to find binary list #{cbl.project.name} #{cbl.repository.name} #{cbl.architecture.name}" unless p
      # update...
      _update_from_xml_binaries(cbl, p)
    }
    save
  end

  def branch_channel_package_into_project(project)
    cp = self.package

    # create a package container
    tpkg = Package.new(:name => self.name, :title => cp.title, :description => cp.description)
    project.packages << tpkg
    tpkg.store

    # branch sources
    tpkg.branch_from(cp.project.name, cp.name)
    tpkg.sources_changed

    add_channel_repos_to_project(tpkg)
  end

  def add_channel_repos_to_project(tpkg)
    cp = self.package

    if self.channel_targets.empty?
      # not defined in channel, so take all from project
      tpkg.project.branch_to_repositories_from(cp.project, cp, true)
      return
    end

    # defined in channel
    self.channel_targets.each do |ct|
      repo_name = ct.repository.extended_name
      # add repositories
      unless cp.project.repositories.find_by_name(repo_name)
        tpkg.project.add_repository_with_targets(repo_name, ct.repository, [ct.repository]) 
      end
      # enable package
      tpkg.enable_for_repository repo_name unless ct.disabled
    end
  end
end
