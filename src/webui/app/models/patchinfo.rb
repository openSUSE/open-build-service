class Patchinfo < ActiveXML::Base
  class << self
    def make_stub( opt )
     reply = "<patchinfo></patchinfo>"
     return XML::Parser.string(reply).parse.root
    end
  end

  def save
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_patchinfo" : "/source/#{self.init_options[:package]}/_patchinfo"
    begin
      frontend = ActiveXML::Config::transport_for(:package)
      frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
      result = {:type => :note, :msg => "Patchinfo sucessfully updated!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Saving Patchinfo failed: #{ActiveXML::Transport.extract_error_message( e )[0]}"}
    end

    return result
  end

  def delete_bugzilla(delete_bug)
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_patchinfo" : "/source/#{self.init_options[:project]}/_patchinfo"
    self.each_bugzilla do |f|
      if f.text == delete_bug
        self.delete_element(f)
      end
    end
    begin
      frontend = ActiveXML::Config::transport_for( :package )
      frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
      result = {:type => :note, :msg => "Bug removed!"}
   rescue ActiveXML::Transport::Error => e
      message, code, api_exception = ActiveXML::Transport.extract_error_message e
      result = {:type => :error, :msg => "Deleting bug failed: " + message }
    end

    return result

  end

  def set_buglist(buglist, bugzilla)
    if self.each_bugzilla == nil
      self.add_element('bugzilla')
    end
    buglist.each do |bug|
      self.each_bugzilla do |f|
        if f.text == bug
          # delete bug when already set
          self.delete_element(f)
        end
      end
    end

    for x in buglist do
      bug = self.add_element('bugzilla')
      bug.text = x
    end

  end  
  
  def set_binaries(binaries, name)
    if self.each_binary == nil
      self.add_element('binaries')
    end
    self.each_binary do |b|
      # delete all binaries which already set
      self.delete_element(b)
    end
    
    for x in binaries do
      binary = self.add_element('binary')
      binary.text = x
    end

  end

end

