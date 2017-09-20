# API for accessing to the backend
module Backend
  module Api
    module Sources
      module Package
        # Returns the attribute content
        def self.attributes(project, package, revision)
          path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1"
          path += "&rev=#{CGI.escape(revision)}" if revision
          Backend::Connection.get(path).body
        end

        # Writes the xml for attributes
        def self.write_attributes(project, package, login, xml, comment)
          path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1&user=#{CGI.escape(login)}"
          path += "&comment=#{CGI.escape(comment)}" if comment
          Backend::Connection.put(path, xml)
        end

        # Returns a file list of the sources for a package
        def self.files(project, package, options = {})
          path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}"
          path += "?#{options.to_query}" if options.present?
          Backend::Connection.get(path).body.force_encoding("UTF-8")
        end

        # Returns the revisions (mrev) list for a package
        def self.revisions(project, package)
          Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_history?deleted=1&meta=1").body
        end

        # Returns the meta file from a package
        def self.meta(project, package)
          Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_meta").body.force_encoding('UTF-8')
        end

        # It triggers all the services of a package (from src/api/app/controllers/webui/package_controller.rb)
        def self.trigger_services(project, package, user)
          Backend::Connection.post("/source/#{CGI.escape(project)}/#{CGI.escape(package)}?cmd=runservice&user=#{CGI.escape(user)}")
        end

        # Writes the patchinfo
        def self.write_patchinfo(project, package, login, xml, comment = nil)
          path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_patchinfo?user=#{CGI.escape(login)}"
          path += "&comment=#{CGI.escape(comment)}" if comment
          Backend::Connection.put(path, xml)
        end

        # Runs the command waitservice for that project/package
        def self.wait_service(project, package)
          Backend::Connection.post("/source/#{CGI.escape(project)}/#{CGI.escape(package)}?cmd=waitservice")
        end

        # Runs the command mergeservice for that project/package
        def self.merge_service(project, package, login)
          Backend::Connection.post("/source/#{CGI.escape(project)}/#{CGI.escape(package)}?cmd=mergeservice&user=#{CGI.escape(login)}")
        end

        # Runs the command runservice for that project/package
        def self.run_service(project, package, login)
          Backend::Connection.post("/source/#{CGI.escape(project)}/#{CGI.escape(package)}?cmd=runservice&user=#{CGI.escape(login)}")
        end

        # Copy a package into another project
        def self.copy(target_project, target_package, source_project, source_package, login, options = {})
          path = "/source/#{CGI.escape(target_project)}/#{CGI.escape(target_package)}"
          query_hash = { cmd: :copy, oproject: source_project, opackage: source_package, user: login }
          query_hash.merge!(options.slice(:keeplink, :expand, :comment))
          path += "?#{query_hash.to_query}"
          Backend::Connection.post(path)
        end

        # Writes the link information of a package
        def self.write_link(project, package, login, xml)
          Backend::Connection.put("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_link?user=#{CGI.escape(login)}", xml)
        end

        # Returns the source diff
        def self.source_diff(project, package, options = {})
          path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}"
          query_hash = { cmd: :diff, view: :xml, withissues: 1 }
          query_hash.merge!(options.slice(:rev, :orev, :opackage, :oproject, :linkrev, :olinkrev, :expand))
          path += "?#{query_hash.to_query}"
          Backend::Connection.post(path).body.force_encoding('UTF-8')
        end

        # Runs the command rebuild for that project/package
        def self.rebuild(project, package, options = {})
          path = "/build/#{CGI.escape(project)}"
          query_hash = { cmd: :rebuild, package: package }
          query_hash.merge!(options.slice(:repository, :arch))
          path += "?#{query_hash.to_query}"
          Backend::Connection.post(path)
        end

        # Returns the content of the source file
        def self.file(project, package, filename)
          Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/#{CGI.escape(filename)}").body.force_encoding('UTF-8')
        end

        # Writes the content of the source file
        def self.write_file(project, package, filename, content = '')
          Backend::Connection.put("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/#{CGI.escape(filename)}", content)
        end
      end
    end
  end
end
