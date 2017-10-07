module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to source packages
      module Package
        extend Backend::ConnectionHelper

        # Returns the attributes content
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param revision [String] Revision hash/number.
        # @return [String] The XML with the attributes content
        def self.attributes(project, package, revision)
          params = { meta: 1 }
          params[:rev] = revision if revision
          get(["/source/:project/:package/_attribute", project, package || '_project'], params: params)
        end

        # Writes the content in xml for attributes
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @param content [String] XML with the content to write.
        # @param comment [String] Comment to attach to this operation.
        # @return [String]
        def self.write_attributes(project, package, user, content, comment)
          params = { meta: 1, user: user }
          params[:comment] = comment if comment
          put(["/source/:project/:package/_attribute", project, package || '_project'],
              data: content, params: params)
        end

        # Returns a file list of the sources for a package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param options [Hash] Parameters to pass to the backend.
        # @return [String] The XML with the list of files
        def self.files(project, package, options = {})
          get(["/source/:project/:package", project, package], params: options)
        end

        # Returns the revisions (mrev) list for a package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @return [String] The XML with the revisions list
        def self.revisions(project, package)
          get(["/source/:project/:package/_history", project, package], params: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @return [String] The content of the meta file
        def self.meta(project, package)
          get(["/source/:project/:package/_meta", project, package])
        end

        # It triggers all the services of a package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @return [String]
        def self.trigger_services(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :runservice, user: user })
        end

        # Writes the patchinfo
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @param content [String] XML with the content to write.
        # @param comment [String] Optional comment to attach to this operation.
        # @return [String]
        def self.write_patchinfo(project, package, user, content, comment = nil)
          params = { user: user }
          params[:comment] = comment if comment
          put(["/source/:project/:package/_patchinfo", project, package], data: content, params: params)
        end

        # Runs the command waitservice for that project/package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @return [String]
        def self.wait_service(project, package)
          post(["/source/:project/:package", project, package], params: { cmd: :waitservice })
        end

        # Runs the command mergeservice for that project/package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @return [String]
        def self.merge_service(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :mergeservice, user: user })
        end

        # Runs the command runservice for that project/package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @return [String]
        def self.run_service(project, package, user)
          post(["/source/:project/:package", project, package], params: { cmd: :runservice, user: user })
        end

        # Copy a package into another project
        # @param target_project [String] Name of the target project.
        # @param target_package [String] Name of the target package.
        # @param source_project [String] Name of the source project.
        # @param source_package [String] Name of the source package.
        # @param user [String] Login of the user.
        # @option options [String] :keeplink Stay on revision after copying.
        # @option options [String] :comment Comment to attach to this operation.
        # @option options [String] :expand Expand sources.
        # @return [String]
        def self.copy(target_project, target_package, source_project, source_package, user, options = {})
          post(["/source/:project/:package", target_project, target_package],
               defaults: { cmd: :copy, oproject: source_project, opackage: source_package, user: user },
               params: options, accepted: [:keeplink, :expand, :comment])
        end

        # Writes the link information of a package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param user [String] Login of the user.
        # @param content [String] XML with the content to write.
        # @return [String]
        def self.write_link(project, package, user, content)
          put(["/source/:project/:package/_link", project, package], data: content, params: { user: user })
        end

        # Returns the source diff
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @option options [String] :rev Revision Hash/Number.
        # @option options [String] :orev Origin revision Hash/Number.
        # @option options [String] :opackage Origin package name.
        # @option options [String] :oproject Origin project name.
        # @option options [String] :linkrev Use the revision of the linked package.
        # @option options [String] :olinkrev Use the origin revision of the linked package.
        # @option options [String] :expand Expand sources.
        # @return [String]
        def self.source_diff(project, package, options = {})
          post(["/source/:project/:package", project, package], defaults: { cmd: :diff, view: :xml, withissues: 1 },
               params: options, accepted: [:rev, :orev, :opackage, :oproject, :linkrev, :olinkrev, :expand])
        end

        # Runs the command rebuild for that package
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @option options [String] :repository Build only for that repository.
        # @option options [String] :arch Build only for that architecture.
        # @return [String]
        def self.rebuild(project, package, options = {})
          post(["/build/:project", project], defaults: { cmd: :rebuild, package: package }, params: options, accepted: [:repository, :arch])
        end

        # Returns the content of the source file
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param filename [String] Name of the file.
        # @return [String] The content of the file
        def self.file(project, package, filename)
          get(["/source/:project/:package/:filename", project, package, filename])
        end

        # Writes the content of the source file
        # @param project [String] Name of the project.
        # @param package [String] Name of the package.
        # @param filename [String] Name of the file.
        # @param content [String] XML with the content to write.
        # @return [String]
        def self.write_file(project, package, filename, content = '')
          put(["/source/:project/:package/:filename", project, package, filename], data: content)
        end
      end
    end
  end
end
