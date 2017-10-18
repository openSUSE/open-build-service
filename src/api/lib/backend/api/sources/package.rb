# API for accessing to the backend
module Backend
  module Api
    module Sources
      module Package
        extend Backend::ConnectionHelper

        # Returns the attributes content
        def self.attributes(project, package, revision)
          params = { meta: 1 }
          params[:rev] = revision if revision
          get(["/source/:project/:package/_attribute", project, package || '_project'], params: params)
        end

        # Writes the content in xml for attributes
        def self.write_attributes(project, package, user, content, comment)
          params = { meta: 1, user: user }
          params[:comment] = comment if comment
          put(["/source/:project/:package/_attribute", project, package || '_project'],
              data: content, params: params)
        end

        # Returns a file list of the sources for a package
        def self.files(project, package, options = {})
          get(["/source/:project/:package", project, package], params: options)
        end

        # Returns the revisions (mrev) list for a package
        def self.revisions(project, package)
          get(["/source/:project/:package/_history", project, package], params: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a package
        def self.meta(project, package)
          get(["/source/:project/:package/_meta", project, package])
        end

        # It triggers all the services of a package
        def self.trigger_services(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :runservice, user: user })
        end

        # Writes the patchinfo
        def self.write_patchinfo(project, package, user, content, comment = nil)
          params = { user: user }
          params[:comment] = comment if comment
          put(["/source/:project/:package/_patchinfo", project, package], data: content, params: params)
        end

        # Runs the command waitservice for that project/package
        def self.wait_service(project, package)
          post(["/source/:project/:package", project, package], params: { cmd: :waitservice })
        end

        # Runs the command mergeservice for that project/package
        def self.merge_service(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :mergeservice, user: user })
        end

        # Runs the command runservice for that project/package
        def self.run_service(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :runservice, user: user })
        end

        # Copy a package into another project
        def self.copy(target_project, target_package, source_project, source_package, user, options = {})
          post(["/source/:project/:package", target_project, target_package],
               defaults: { cmd: :copy, oproject: source_project, opackage: source_package, user: user },
               params: options, accepted: [:keeplink, :expand, :comment])
        end

        # Writes the link information of a package
        def self.write_link(project, package, user, content)
          put(["/source/:project/:package/_link", project, package], data: content, params: { user: user })
        end

        # Returns the source diff
        def self.source_diff(project, package, options = {})
          post(["/source/:project/:package", project, package], defaults: { cmd: :diff, view: :xml, withissues: 1 },
               params: options, accepted: [:rev, :orev, :opackage, :oproject, :linkrev, :olinkrev, :expand])
        end

        # Runs the command rebuild for that project/package
        def self.rebuild(project, package, options = {})
          post(["/build/:project", project], defaults: { cmd: :rebuild, package: package }, params: options, accepted: [:repository, :arch])
        end

        # Returns the content of the source file
        def self.file(project, package, filename)
          get(["/source/:project/:package/:filename", project, package, filename])
        end

        # Writes the content of the source file
        def self.write_file(project, package, filename, content = '')
          put(["/source/:project/:package/:filename", project, package, filename], data: content)
        end
      end
    end
  end
end
