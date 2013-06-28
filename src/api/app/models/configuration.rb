require 'opensuse/backend'

class Configuration < ActiveRecord::Base
  after_save :write_to_backend

  def write_to_backend()
    path = "/configuration"
    logger.debug "Write configuration information to backend..."
    Suse::Backend.put_source(path, self.render_axml)
  end

  def render_axml()
    builder = Nokogiri::XML::Builder.new

    builder.configuration() do |configuration|
      configuration.title( self.title || "" )
      configuration.description( self.description || "" )
      configuration.name( self.name || "" )

      configuration.schedulers do |schedulers|
        Architecture.where(:available => 1).each do |arch|
          schedulers.arch( arch.name )
        end
      end
    end

    return builder.doc.to_xml :indent => 2, :encoding => 'UTF-8',
                              :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION |
                                            Nokogiri::XML::Node::SaveOptions::FORMAT
  end
end
