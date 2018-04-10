# frozen_string_literal: true
class Directory < ActiveXML::Node
  def self.hashed(opts)
    project = opts.delete :project
    package = opts.delete :package
    begin
      Xmlhash.parse(Backend::Api::Sources::Package.files(project, package, opts))
    rescue ActiveXML::Transport::Error => e
      logger.debug "Error fetching source file list for #{project}/#{package} #{e.inspect}"
      return Xmlhash::XMLHash.new(error: e.summary)
    end
  end
end
