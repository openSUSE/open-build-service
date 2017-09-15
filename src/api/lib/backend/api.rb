# API for accessing to the backend
module Backend
  class Api
    # Returns the attribute content (from src/api/app/controllers/attribute_controller.rb)
    def self.attribute(project, package, revision)
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1"
      path += "&rev=#{CGI.escape(revision)}" if revision
      Backend::Connection.get(path).body
    end

    # Writes the xml for attributes (from src/api/app/mixins/has_attributes.rb)
    def self.write_attributes(project, package, login, xml, comment)
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_attribute?meta=1&user=#{CGI.escape(login)}"
      path += "&comment=#{CGI.escape(comment)}" if comment
      Backend::Connection.put(path, xml)
    end

    # Returns a file list of binaries (from src/api/app/controllers/build/file_controller.rb)
    def self.binary_files_list(project, repository, arch, package)
      Backend::Connection.get("/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(arch)}/#{CGI.escape(package)}").body
    end

    # Returns a file list of the sources for a package
    def self.file_list(project, package, options = {})
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}"
      path += "?#{options.to_query}" if options.present?
      Backend::Connection.get(path).body.force_encoding("UTF-8")
    end

    # Returns the revisions list for a package / project using mrev (from src/api/app/helpers/validation_helper.rb)
    def self.revisions_list(project, package = nil)
      Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package || '_project')}/_history?deleted=1&meta=1").body
    end

    # Returns the meta file from a deleted project (from src/api/app/helpers)
    def self.meta_from_deleted_project(project, revision)
      Backend::Connection.get("/source/#{CGI.escape(project)}/_project/_meta?rev=#{CGI.escape(revision)}&deleted=1").body
    end

    # Returns the meta file from a project
    def self.meta_from_project(project)
      Backend::Connection.get("/source/#{CGI.escape(project)}/_project/_meta").body.force_encoding('UTF-8')
    end

    # Returns the meta file from a project/package
    def self.meta_from_package(project, package)
      Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_meta").body.force_encoding('UTF-8')
    end

    # It triggers all the services of a package (from src/api/app/controllers/webui/package_controller.rb)
    def self.trigger_services(project, package, user)
      Backend::Connection.post("/source/#{CGI.escape(project)}/#{CGI.escape(package)}?cmd=runservice&user=#{CGI.escape(user)}")
    end

    # Returns the notification payload for that key (from src/api/app/models/binary_release.rb)
    def self.notification_payload(key)
      Backend::Connection.get("/notificationpayload/#{key}").body
    end

    # Deletes the notification payload for that key (from src/api/app/models/binary_release.rb)
    def self.delete_notification_payload(key)
      Backend::Connection.delete("/notificationpayload/#{key}")
    end

    # Returns the patchinfo for that reference
    def self.patchinfo(reference)
      Backend::Connection.get("/source/#{CGI.escape(reference)}/_patchinfo").body
    end

    # Writes the patchinfo
    def self.write_patchinfo(project, package, login, xml, comment = nil)
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_patchinfo?user=#{CGI.escape(login)}"
      path += "&comment=#{CGI.escape(comment)}" if comment
      Backend::Connection.put(path, xml)
    end

    # It writes the configuration XML
    def self.write_configuration(xml)
      Backend::Connection.put('/configuration', xml)
    end

    # Performs a search of the binary in a project list
    def self.binary_search(projects, name)
      project_list = projects.map { |project| "@project='#{CGI.escape(project.name)}'" }.join('+or+')
      Backend::Connection.post("/search/published/binary/id?match=(@name='#{CGI.escape(name)}'+and+(#{project_list}))").body
    end

    # Returns the jobs history for a project
    def self.job_history(project, repository, arch)
      Backend::Connection.get("/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(arch)}/_jobhistory?code=lastfailures").body
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

    # Returns the latest notifications specifying a starting point
    def self.last_notifications(start)
      Backend::Connection.get("/lastnotifications?start=#{CGI.escape(start.to_s)}&block=1").body
    end

    # Writes a Project configuration
    def self.write_project_configuration(project, configuration)
      Backend::Connection.put("/source/#{CGI.escape(project)}/_config", configuration)
    end

    # Returns the download url for a repository
    def self.download_url_for_repository(project, repository)
      Backend::Connection.get("/published/#{CGI.escape(project)}/#{CGI.escape(repository)}?view=publishedpath").body
    end

    # Returns the download url for a package
    def self.download_url_for_package(project, repository, package, architecture, file)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/#{CGI.escape(file)}"
      Backend::Connection.get("#{path}?view=publishedpath").body
    end

    # Copy a package into another project
    def self.copy_package(target_project, target_package, source_project, source_package, login, options = {})
      path = "/source/#{CGI.escape(target_project)}/#{CGI.escape(target_package)}"
      query_hash = { cmd: :copy, oproject: source_project, opackage: source_package, user: login }
      query_hash.merge!(options.slice(:keeplink, :expand, :comment))
      path += "?#{query_hash.to_query}"
      Backend::Connection.post(path)
    end

    # Writes the link information of a package
    def self.write_link_of_package(project, package, login, xml)
      Backend::Connection.put("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/_link?user=#{CGI.escape(login)}", xml)
    end

    # Notifies a certain plugin with the payload
    def self.notify_plugin(plugin, payload)
      Backend::Connection.post("/notify_plugins/#{plugin}", Yajl::Encoder.encode(payload), 'Content-Type' => 'application/json').body
    end

    # Returns the KeyInfo file for the project
    def self.key_info(project)
      Backend::Connection.get("/source/#{CGI.escape(project)}/_keyinfo?withsslcert=1&donotcreatecert=1").body
    end

    def self.move_project(source_project, target_project)
      Backend::Connection.post("/source/#{CGI.escape(target_project)}?cmd=move&oproject=#{CGI.escape(source_project)}")
    end

    # Returns a chunk of the build's log
    def self.log_chunk(project, package, repository, architecture, starting, ending)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_log"
      path += "?nostream=1&start=#{starting.to_i}&end=#{ending.to_i}"
      Backend::Connection.get(path).body.force_encoding("UTF-8")
    end

    # Returns the job status of a build
    def self.job_status(project, package, repository, architecture)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_jobstatus"
      Backend::Connection.get(path).body
    end

    # Returns the result view for a build
    def self.build_result(project, package, repository, architecture)
      path = "/build/#{CGI.escape(project)}/_result"
      path += "?view=status&package=#{CGI.escape(package)}&arch=#{CGI.escape(architecture)}&repository=#{CGI.escape(repository)}"
      Backend::Connection.get(path).body.force_encoding("UTF-8")
    end

    # Returns the log's size for a build
    def self.build_log_size(project, package, repository, architecture)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/_log?view=entry"
      Backend::Connection.get(path).body
    end

    # Returns the log's size for a build
    def self.build_problems(project)
      path = "/build/#{CGI.escape(project)}/_result?view=status&code=failed&code=broken&code=unresolvable"
      Backend::Connection.get(path).body
    end

    # Returns the RPMlint log
    def self.rpmlint_log(project, package, repository, architecture)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/#{CGI.escape(package)}/rpmlint.log"
      Backend::Connection.get(path).body.force_encoding("UTF-8")
    end

    # Returns the build dependency information
    def self.build_dependency_info(project, package, repository, architecture)
      path = "/build/#{CGI.escape(project)}/#{CGI.escape(repository)}/#{CGI.escape(architecture)}/_builddepinfo"
      path += "?package=#{CGI.escape(package)}&view=pkgnames"
      Backend::Connection.get(path).body.force_encoding("UTF-8")
    end

    # Returns the worker's status
    def self.worker_status
      Backend::Connection.get('/build/_workerstatus').body.force_encoding("UTF-8")
    end

    # Returns the source diff
    def self.source_diff(project, package, options = {})
      path = "/source/#{CGI.escape(project)}/#{CGI.escape(package)}"
      query_hash = { cmd: :diff, view: :xml, withissues: 1 }
      query_hash.merge!(options.slice(:rev, :orev, :opackage, :oproject, :linkrev, :olinkrev, :expand))
      path += "?#{query_hash.to_query}"
      Backend::Connection.post(path).body.force_encoding('UTF-8')
    end

    # Pings the root of the backend
    def self.root
      Backend::Connection.get('/').body.force_encoding("UTF-8")
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
    def self.source_file(project, package, filename)
      Backend::Connection.get("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/#{CGI.escape(filename)}").body.force_encoding('UTF-8')
    end

    # Writes the content of the source file
    def self.write_source_file(project, package, filename, content = '')
      Backend::Connection.put("/source/#{CGI.escape(project)}/#{CGI.escape(package)}/#{CGI.escape(filename)}", content)
    end
  end
end
