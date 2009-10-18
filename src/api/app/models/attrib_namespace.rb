# Specifies own namespaces of attributes
# always only 1-level deep, unlike project namespaces

class AttribNamespace < ActiveRecord::Base
  has_many :attrib_types, :dependent => :destroy
  belongs_to :db_project


  def update_from_xml(node)
#    self.name = node.name

# FIXME: store  permissions
  
    self.save
  end

  def render_axml(node = Builder::XmlMarkup.new(:indent=>2))
# FIXME: render  permissions
    node.namespace(:name => self.name)
  end

  def self.anscache
    return @cache if @cache
    @cache = Hash.new
    find(:all).each do |ns|
      @cache[ns.name] = ns
    end
    return @cache
  end

  def anscache
    self.class.anscache
  end

  def after_create
    logger.debug "updating attrib namespace cache (new ns '#{name}', id \##{id})"
    anscache[name] = self
  end

  def after_update
    logger.debug "updating attrib namespace cache (ns name for id \##{id} changed to '#{name}')"
    anscache.each do |k,v|
      if v.id == id
        anscache.delete k
        break
      end
    end
    anscache[name] = self
  end

  def after_destroy
    logger.debug "updating attrib namespace cache (role '#{name}' deleted)"
    anscache.delete name
  end

end
