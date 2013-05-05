class Attribute < ActiveXML::Node

  class << self
    def make_stub( opt )
     "<attributes/>"
    end
  end

  # We need to implement these methods on our own here, because this class is used
  # for package and project attributes...
  def save
    path = self.init_options[:package] ? "/source/#{self.init_options[:project]}/#{self.init_options[:package]}/_attribute" : "/source/#{self.init_options[:project]}/_attribute"
    begin
      frontend = ActiveXML::transport 
      frontend.direct_http URI("#{path}"), :method => "POST", :data => self.dump_xml
      result = {:type => :notice, :msg => "Attribute sucessfully added!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Saving attribute failed: #{e.summary}"}
    end

    return result 
  end

  def delete(namespace, name)
    package = self.init_options[:package]
    if package
      path = "/source/#{self.init_options[:project]}/#{package}/_attribute/#{namespace}:#{name}"
    else
      path = "/source/#{self.init_options[:project]}/_attribute/#{namespace}:#{name}"
    end

    begin
      frontend = ActiveXML::transport
      frontend.direct_http URI("#{path}"), :method => "DELETE", :data => ""
      result = {:type => :notice, :msg => "Attribute sucessfully deleted!"}
    rescue ActiveXML::Transport::Error => e
      result = {:type => :error, :msg => "Deleting attribute failed: " + e.summary }
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
    
    unless values.kind_of? Array
      values = [values]
    end

    new_attr = self.add_element 'attribute', 'name' => name, 'namespace' => namespace
    for x in values do
      value = new_attr.add_element 'value'
      value.text = x
    end

  end


end
