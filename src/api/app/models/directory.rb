class Directory
  def self.hashed(opts)
    project = opts.delete :project
    package = opts.delete :package
    begin
      Xmlhash.parse(Backend::Api::Sources::Package.files(project, package, opts))
    rescue Backend::Error => e
      Rails.logger.debug "Error fetching source file list for #{project}/#{package} #{e.inspect}"
      return Xmlhash::XMLHash.new(error: e.summary)
    end
  end
end
