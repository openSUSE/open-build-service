class Directory < ActiveXML::Node

  def self.hashed(opts)
    path = "/source/#{opts[:project]}/#{opts[:package]}"
    if opts[:expand]
      path += "/?expand=1"
    end
    d = nil
    begin
      d = Suse::Backend.get(path).body
    rescue ActiveXML::Transport::Error => e
      logger.debug "fetching #{path} #{e.inspect}"
      return Xmlhash::XMLHash.new(error: e.summary)
    end
    Xmlhash.parse(d)
  end
end
