class Channel < ActiveRecord::Base

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

  def update_from_xml(xmlhash, check=false)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.is_a? String
    xmlhash.elements('target') { |p|
      prj = Project.find_by_name(p['project'])
      r = prj.repositories.find_by_name(p['repository'])
      self.channel_targets.build(:repository => r, :id_template => p['id_template']) if r
    }
    xmlhash.elements('binaries').each { |p|
      cbl = self.channel_binary_lists.build()
      project = p['project']
      unless project.blank?
        cbl.project = Project.find_by_name( project )
        cbl.repository = cbl.project.repositories.find_by_name( p['repository'] ) if p['repository']
      end
      cbl.architecture = Architecture.find_by_name( p['arch'] ) if p['arch']
      cbl.save
      p.elements('binary') { |b|
        binary = cbl.channel_binaries.build( name: b['name'] )
        binary.binaryarch = b['binaryarch']
        binary.supportstatus = b['supportstatus']
        binary.architecture = Architecture.find_by_name( b['arch'] ) if b['arch']
        project = b['project']
        binary.project = Project.find_by_name( project ) if project
        binary.package = b['package'] if b['package']
        binary.repository = binary.project.repositories.find_by_name(b['repository'] ) if b['repository']
        binary.save
      }
    }
    self.save
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
      tpkg.enable_for_repository repo_name
    end
  end
end
