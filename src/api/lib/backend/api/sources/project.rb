# API for accessing to the backend
module Backend
  module Api
    module Sources
      class Project
        # Returns the attributes for the project
        def self.attributes(project, revision)
          path = "/source/#{CGI.escape(project)}/_project/_attribute?meta=1"
          path += "&rev=#{CGI.escape(revision)}" if revision
          Backend::Connection.get(path).body
        end

        # Writes the xml for attributes
        def self.write_attributes(project, login, xml, comment)
          path = "/source/#{CGI.escape(project)}/_project/_attribute?meta=1&user=#{CGI.escape(login)}"
          path += "&comment=#{CGI.escape(comment)}" if comment
          Backend::Connection.put(path, xml)
        end

        # Returns the revisions (mrev) list for a project
        def self.revisions(project)
          Backend::Connection.get("/source/#{CGI.escape(project)}/_project/_history?deleted=1&meta=1").body
        end

        # Returns the meta file from a project
        def self.meta(project, options = {})
          path = "/source/#{CGI.escape(project)}/_project/_meta"
          options.slice!(:revision, :deleted)
          options[:rev] = options.delete(:revision)
          path += "?#{options.to_query}" unless options.empty?
          Backend::Connection.get(path).body.force_encoding('UTF-8')
        end

        # Writes a Project configuration
        def self.write_configuration(project, configuration)
          Backend::Connection.put("/source/#{CGI.escape(project)}/_config", configuration)
        end

        # Returns the KeyInfo file for the project
        def self.key_info(project)
          Backend::Connection.get("/source/#{CGI.escape(project)}/_keyinfo?withsslcert=1&donotcreatecert=1").body
        end

        # Returns the patchinfo for the project
        def self.patchinfo(project)
          Backend::Connection.get("/source/#{CGI.escape(project)}/_patchinfo").body
        end

        # Moves the source project to the target
        def self.move(source, target)
          Backend::Connection.post("/source/#{CGI.escape(target)}?cmd=move&oproject=#{CGI.escape(source)}")
        end
      end
    end
  end
end
