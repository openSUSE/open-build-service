class Channel < ActiveRecord::Base

  belongs_to :package, foreign_key: :package_id
  has_many :channel_targets, dependent: :destroy
  has_many :channel_binary_lists, dependent: :destroy

  class UnknownPackageError < APIException
    setup 'unknown_package', 404, "Unknown referenced package"
  end
  class UnknownRepositoryError < APIException
    setup 'unknown_repository', 404, "Unknown referenced repository"
  end

  def self.verify_xml!(xmlhash)
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.class == String
    xmlhash.elements('target') { |p|
      prj = Project.get_by_name(p.value("project"))
      r = prj.repositories.find_by_name(p.value("repository"))
      raise UnknownRepositoryError.new "Repository does not exist #{prj.name}/#{p.value("repository")}" unless r
    }
    xmlhash.elements('binaries').each { |p|
      project = p.value("project")
      unless project.blank?
        prj = Project.get_by_name( p.value("project") )
        prj.repositories.find_by_name!( p.value("repository") ) if p.value("repository")
      end
      Architecture.find_by_name!( p.value("arch") ) if p.value("arch")
      p.elements('binary') { |b|
        Architecture.find_by_name!( b.value("arch") ) if b.value("arch")
        project = b.value("project")
        if project
          prj = Project.get_by_name( project )
          if b.value("package")
            pkg = prj.find_package(b.value("package") )
            raise UnknownPackageError.new "Package does not exist #{prj.name}/#{p.value("package")}" unless pkg
          end
          if b.value("repository")
            r = prj.repositories.find_by_name!(b.value("repository") )
            raise UnknownRepositoryError.new "Repository does not exist #{prj.name}/#{p.value("repository")}" unless r
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
    xmlhash = Xmlhash.parse(xmlhash) if xmlhash.class == String
    xmlhash.elements('target') { |p|
      prj = Project.find_by_name(p.value("project"))
      r = prj.repositories.find_by_name(p.value("repository"))
      self.channel_targets.create(:repository => r) if r
    }
    xmlhash.elements('binaries').each { |p|
      cbl = self.channel_binary_lists.create()
      project = p.value("project")
      unless project.blank?
        cbl.project = Project.find_by_name( project )
        cbl.repository = cbl.project.repositories.find_by_name( p.value("repository") ) if p.value("repository")
      end
      cbl.architecture = Architecture.find_by_name( p.value("arch") ) if p.value("arch")
      cbl.save
      p.elements('binary') { |b|
        binary = cbl.channel_binaries.create( name: b.value("name") )
        binary.binaryarch = b.value("binaryarch")
        binary.architecture = Architecture.find_by_name( b.value("arch") ) if b.value("arch")
        project = b.value("project")
        if project
          binary.project = Project.find_by_name( project )
          binary.package = b.value("package") if b.value("package")
          binary.repository = binary.project.repositories.find_by_name(b.value("repository") ) if b.value("repository")
        end
        binary.save
      }
    }
    self.save
  end

end
