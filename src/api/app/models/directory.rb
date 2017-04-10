class Directory < ActiveXML::Node
  def self.hashed(opts)
    project = opts.delete :project
    package = opts.delete :package
    path = Package.source_path(project, package, nil, opts)
    d = nil
    begin
      d = Backend::Connection.get(path).body
    rescue ActiveXML::Transport::Error => e
      logger.debug "fetching #{path} #{e.inspect}"
      return Xmlhash::XMLHash.new(error: e.summary)
    end
    Xmlhash.parse(d)
  end
end
