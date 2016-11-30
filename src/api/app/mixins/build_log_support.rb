module BuildLogSupport
  include Escaper

  def raw_log_chunk( project, package, repo, arch, start, theend )
    logger.debug "get log chunk #{start}-#{theend}"
    path = "/build/#{pesc project}/#{pesc repo}/#{pesc arch}/#{pesc package}/_log?nostream=1&start=#{start}&end=#{theend}"
    ActiveXML::backend.direct_http URI("#{path}"), timeout: 500
  end

  def get_log_chunk( project, package, repo, arch, start, theend )
    log = raw_log_chunk( project, package, repo, arch, start, theend )
    begin
      log.encode!(invalid: :replace, undef: :replace, cr_newline: true)
    rescue Encoding::UndefinedConversionError
      # encode is documented not to throw it if undef: is :replace, but at least we tried - and ruby 1.9.3 is buggy
    end
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

  def get_size_of_log( project, package, repo, arch)
    logger.debug 'get log entry'
    path = "/build/#{pesc project}/#{pesc repo}/#{pesc arch}/#{pesc package}/_log?view=entry"
    data = ActiveXML::backend.direct_http URI("#{path}"), timeout: 500
    return 0 unless data
    doc = Xmlhash.parse(data)
    doc.elements('entry') do |e|
      return e['size'].to_i
    end
    0
  end

  def get_job_status( project, package, repo, arch)
    path = "/build/#{pesc project}/#{pesc repo}/#{pesc arch}/#{pesc package}/_jobstatus"
    ActiveXML::backend.direct_http URI("#{path}"), timeout: 500
  end
end
