module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to source packages
      module Package
        extend Backend::ConnectionHelper

        # Returns the attributes content
        # @param revision [String] Revision hash/number.
        # @return [String]
        def self.attributes(project_name, package_name, options = {})
          params = { meta: 1 }
          params[:rev]  = options[:rev]  if options[:rev]
          params[:view] = options[:view] if options[:view]
          http_get(['/source/:project/:package/_attribute', project_name, package_name || '_project'],
                   params: params, accepted: %i[rev meta view])
        end

        # Writes the content in xml for attributes
        # @return [String]
        def self.write_attributes(project_name, package_name, user_login, content)
          params = { meta: 1, user: user_login }
          http_put(['/source/:project/:package/_attribute', project_name, package_name || '_project'],
                   data: content, params: params)
        end

        # Returns a file list of the sources for a package
        # @param options [Hash] Parameters to pass to the backend.
        # @return [String]
        def self.files(project_name, package_name, options = {})
          http_get(['/source/:project/:package', project_name, package_name], params: options, accepted: %i[expand rev view])
        end

        # Returns the revisions (mrev) list for a package
        # @return [String]
        def self.revisions(project_name, package_name, options = {})
          http_get(['/source/:project/:package/_history', project_name, package_name], params: options,
                                                                                       accepted: %i[meta rev deleted limit startbefore],
                                                                                       defaults: { meta: 1, deleted: 1 })
        end

        # Returns the meta file from a package
        # @return [String]
        def self.meta(project_name, package_name)
          http_get(['/source/:project/:package/_meta', project_name, package_name])
        end

        # Returns the content of the _service file (if present)
        # @return [String]
        def self.service(project_name, package_name)
          http_get(['/source/:project/:package/_service', project_name, package_name])
        rescue Backend::NotFoundError
          nil
        end

        # It triggers all the services of a package
        # @return [String]
        def self.trigger_services(project_name, package_name, user_login, comment = nil)
          params = { cmd: :runservice, user: user_login, comment: comment }.compact
          http_post(['/source/:project/:package', project_name, package_name], params: params)
        end

        # Writes the patchinfo
        # @return [String]
        def self.write_patchinfo(project_name, package_name, user_login, content, comment = nil)
          params = { user: user_login }
          params[:comment] = comment if comment
          http_put(['/source/:project/:package/_patchinfo', project_name, package_name], data: content, params: params)
        end

        # Runs the command waitservice for that project/package
        # @return [String]
        def self.wait_service(project_name, package_name)
          http_post(['/source/:project/:package', project_name, package_name], params: { cmd: :waitservice })
        end

        # Runs the command mergeservice for that project/package
        # @return [String]
        def self.merge_service(project_name, package_name, user_login)
          http_post(['/source/:project/:package', project_name, package_name], params: { cmd: :mergeservice, user: user_login })
        end

        # Copy a package into another project
        # @option options [String] :keeplink Stay on revision after copying.
        # @option options [String] :comment Comment to attach to this operation.
        # @option options [String] :expand Expand sources.
        # @return [String]
        def self.copy(target_project_name, target_package_name, source_project_name, source_package_name, user_login, options = {})
          http_post(['/source/:project/:package', target_project_name, target_package_name],
                    defaults: { cmd: :copy, oproject: source_project_name, opackage: source_package_name, user: user_login },
                    params: options, accepted: %i[orev keeplink expand comment requestid withacceptinfo dontupdatesource noservice])
        end

        # Branch a package into another project
        def self.branch(target_project, target_package, source_project, source_package, user, options = {})
          http_post(['/source/:project/:package', source_project, source_package],
                    defaults: { cmd: :branch, oproject: target_project, opackage: target_package, user: user },
                    params: options, accepted: %i[keepcontent comment requestid noservice])
        end

        # Returns the link information of a package
        def self.link_info(project, package)
          http_get(['/source/:project/:package/_link', project, package])
        end

        # Writes the link information of a package
        # @return [String]
        def self.write_link(project_name, package_name, user_login, content)
          http_put(['/source/:project/:package/_link', project_name, package_name], data: content, params: { user: user_login })
        end

        # Returns the source diff as UTF-8 encoded string
        # @option options [String] :rev Revision Hash/Number.
        # @option options [String] :orev Origin revision Hash/Number.
        # @option options [String] :opackage Origin package name.
        # @option options [String] :oproject Origin project name.
        # @option options [String] :linkrev Use the revision of the linked package.
        # @option options [String] :olinkrev Use the origin revision of the linked package.
        # @option options [String] :expand Expand sources.
        # @option options [String] :filelimit Sets the maximum lines of the diff which will be returned (0 = all lines)
        # @return [String]
        def self.source_diff(project_name, package_name, options = {})
          accepted = %i[rev orev opackage oproject linkrev olinkrev expand filelimit tarlimit withissues view cacheonly nodiff file]
          diff = http_post(['/source/:project/:package', project_name, package_name], defaults: { cmd: :diff }, params: options, accepted: accepted)
          diff.valid_encoding? ? diff : diff.encode('UTF-8', 'binary', invalid: :replace, undef: :replace)
        end

        # Runs the command rebuild for that package
        # @option options [String] :repository Build only for that repository.
        # @option options [String] :arch Build only for that architecture.
        # @return [String]
        def self.rebuild(project_name, package_name, options = {})
          http_post(['/build/:project', project_name], defaults: { cmd: :rebuild, package: package_name },
                                                       params: options.compact, accepted: %i[repository arch])
        end

        # Returns the content of the source file
        # @return [String]
        def self.file(project_name, package_name, file_name)
          http_get(['/source/:project/:package/:filename', project_name, package_name, file_name])
        end

        # Returns the content of the source file
        # @return [String]
        def self.blame(project_name, package_name, file_name, options = {})
          http_get(['/source/:project/:package/:filename', project_name, package_name, file_name], defaults: { view: :blame }, params: options, accepted: %i[meta deleted expand rev view])
        end

        # Writes the content of the source file
        # @return [String]
        def self.write_file(project_name, package_name, file_name, content = '', params = {})
          http_put(['/source/:project/:package/:filename', project_name, package_name, file_name], data: content, params: params)
        end

        # Writes source filelist to the package
        # @return [String]
        def self.write_filelist(project_name, package_name, filelist, params = {})
          http_post(['/source/:project/:package', project_name, package_name], defaults: { cmd: :commitfilelist }, data: filelist, params: params)
        end

        # Deletes the package and all the source files inside
        def self.delete(project_name, package_name)
          http_delete(['/source/:project/:package', project_name, package_name])
        end

        # Undeletes the package
        def self.undelete(project_name, package_name, options = {})
          http_post(['/source/:project/:package', project_name, package_name], defaults: { cmd: :undelete },
                                                                               params: options, accepted: %i[user comment time])
        end

        # Deletes a package source file
        def self.delete_file(project_name, package_name, filename)
          http_delete(['/source/:project/:package/:filename', project_name, package_name, filename])
        end
      end
    end
  end
end
