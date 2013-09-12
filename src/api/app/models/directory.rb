class Directory < ActiveXML::Node

  def self.hashed(opts)
    path = "/source/#{opts[:project]}/#{opts[:package]}"
    opts.delete :project
    opts.delete :package
    d = nil
    begin
      d = Suse::Backend.get(path + '?' + opts.to_query).body
    rescue ActiveXML::Transport::Error => e
      logger.debug "fetching #{path} #{e.inspect}"
      return Xmlhash::XMLHash.new(error: e.summary)
    end
    Xmlhash.parse(d)
  end
end
