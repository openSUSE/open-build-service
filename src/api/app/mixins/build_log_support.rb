# frozen_string_literal: true
module BuildLogSupport
  def raw_log_chunk(project, package, repo, arch, start, theend)
    logger.debug "get log chunk #{start}-#{theend}"
    Backend::Api::BuildResults::Status.log_chunk(project.to_s, package.to_s, repo, arch, start, theend)
  end

  def get_log_chunk(project, package, repo, arch, start, theend)
    log = raw_log_chunk(project, package, repo, arch, start, theend)
    log.encode!(invalid: :replace, undef: :replace, cr_newline: true)
    log.gsub(/([^a-zA-Z0-9&;<>\/\n\r \t()])/) do |c|
      begin
        if c.ord < 32
          ''
        else
          c
        end
      rescue ArgumentError
        ''
      end
    end
  end

  def get_size_of_log(project, package, repo, arch)
    logger.debug 'get log entry'
    data = Backend::Api::BuildResults::Status.build_log_size(project.to_s, package.to_s, repo, arch)
    return 0 unless data
    doc = Xmlhash.parse(data)
    doc.elements('entry') do |e|
      return e['size'].to_i
    end
    0
  end

  def get_job_status(project, package, repo, arch)
    Backend::Api::BuildResults::Status.job_status(project.to_s, package.to_s, repo, arch)
  end

  def get_status(project, package, repo, arch)
    data = Backend::Api::BuildResults::Status.build_result(project.to_s, package.to_s, repo, arch)
    return '' unless data
    doc = Xmlhash.parse(data)
    if doc['result'] && doc['result']['status'] && doc['result']['status']['code']
      return doc['result']['status']['code']
    end
    ''
  end
end
