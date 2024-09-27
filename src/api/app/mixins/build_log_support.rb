module BuildLogSupport
  include Ansible

  def raw_log_chunk(project, package_name, repo, arch, start, theend)
    logger.debug "get log chunk #{start}-#{theend}"
    Backend::Api::BuildResults::Status.log_chunk(project.to_s, package_name, repo, arch, start, theend)
  end

  def get_log_chunk(project, package_name, repo, arch, start, theend)
    log = raw_log_chunk(project, package_name, repo, arch, start, theend)
    log.encode!(invalid: :replace, undef: :replace, cr_newline: true)
    log = CGI.escapeHTML(log)
    log.scrub! # Remove invalid byte sequences in UTF-8
    log = ansi_escaped(log, log.length + 1)
    log.gsub(%r{([^a-zA-Z0-9&;<>/\n\r \t()])}) do |c|
      if c.ord < 32
        ''
      else
        c
      end
    rescue ArgumentError
      ''
    end
  end

  def get_size_of_log(project, package_name, repo, arch)
    logger.debug 'get log entry'
    data = Backend::Api::BuildResults::Status.build_log_size(project.to_s, package_name, repo, arch)
    return 0 unless data

    doc = Xmlhash.parse(data)
    doc.elements('entry') do |e|
      return e['size'].to_i
    end
    0
  end

  def get_job_status(project, package_name, repo, arch)
    Backend::Api::BuildResults::Status.job_status(project.to_s, package_name, repo, arch)
  end

  def get_status(project, package_name, repo, arch)
    data = Backend::Api::BuildResults::Status.build_result(project.to_s, package_name, repo, arch)
    return '' unless data

    doc = Xmlhash.parse(data)
    return doc['result']['status']['code'] if doc['result'] && doc['result']['status'] && doc['result']['status']['code']

    ''
  end
end
