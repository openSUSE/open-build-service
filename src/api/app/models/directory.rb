class Directory < ActiveXML::Node

  def self.hashed(opts)
    path = "/source/#{opts[:project]}/#{opts[:package]}"
    if opts[:expand]
      path += "/?expand=1"
    end
    Xmlhash.parse(Suse::Backend.get(path).body)
  end
end
