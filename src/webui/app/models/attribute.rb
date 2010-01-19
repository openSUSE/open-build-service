class Attribute < ActiveXML::Base


  def save
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_attribute" : "/source/#{self.init_options[:project]}/_attribute"
    begin
      frontend = ActiveXML::Config::transport_for( :package ) 
      frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
      result = {:type => :note, :msg => "Attribute sucessfully added!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Saving attribute failed: #{ActiveXML::Transport.extract_error_message( e )[0]}"}
    end

    return result 
  end

  def delete(namespace, name)
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_attribute/#{attribute}" : "/source/#{self.init_options[:project]}/_attribute/#{namespace}:#{name}"
    begin
      frontend = ActiveXML::Config::transport_for( :package )
      frontend.direct_http URI("#{path}"), :method => "DELETE", :data => ""
      result = {:type => :note, :msg => "Attribute sucessfully deleted!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Deleting attribute failed: #{ActiveXML::Transport.extract_error_message( e )[0]}"}
    end

    return result

  end

  def set(namespace, name, values)
    self.each do |f|
      if f.namespace == namespace && f.name == name
        # delete attribute when already set
        self.delete_element(f)
      end
    end
    
    new_attr = self.add_element 'attribute', 'name' => name, 'namespace' => namespace
    for x in values do
      value = new_attr.add_element 'value'
      value.text = x
    end
  end



end
