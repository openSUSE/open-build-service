require 'rexml/document'

class Flag < ActiveRecord::Base
  belongs_to :db_project
  belongs_to :db_package

  #def position=(n) ; raise NoMethodError, "undefined method `postion=' for #{self.inspect}:#{self.class}" ; end

  def to_xml
    raise RuntimeError.new( "FlagError: No flag-status set. \n #{self.inspect}" ) if self.status.nil?
    xml_element = REXML::Element.new(self.status.to_s)
    xml_element.add_attribute REXML::Attribute.new('arch', self.architecture.name) unless self.architecture.nil?
    xml_element.add_attribute REXML::Attribute.new('repository', self.repo) unless self.repo.nil?
    return xml_element
  end

  #TODO This function is not tested yet. Don't use!
  def move_to_top
    if self.position == 1
      return true
    end

    if self.db_package_id.nil?
      flags = Array.new
      flags = self.db_project.flags.find(:all, :conditions => ["type = ?", self.class.to_s])
      logger.debug "Flags*******************"
      logger.debug flags.inspect
      logger.debug "*******************Flags"
      flags.each do |flag|
        flag.position = flag.position + 1
        flag.save unless self == flag
      end

    else
      flags = Array.new
      flags << self.db_package.flags.find_by_type(self.class.to_s)
      flags.each do |flag|
        flag.position = flag.position + 1
        flag.save
      end
    end
    #set my new position
    self.position = 1
    self.save
  end


  def insert_at(pos=1)
    if pos == 0
      raise
    end

    if self.position < pos
      1..(pos-self.position).times do
        unless self.move_lower
          return true
        end
      end
    elsif self.position > pos
      1..(self.position-pos).times do
        self.move_higher
      end
    else
      return true
    end
  end


  def remove_from_list
#    unless self.in_list?
#      return nil
#    end
    pos = self.position
    flags = Flag.find_all_by_type_and_db_project_id_and_db_package_id(self.class.to_s, self.db_project_id, self.db_package_id, :conditions => ["position > ? ", pos])

    Flag.transaction do

      self.destroy

      flags.each do |flag|
        if flag.position > pos
          flag.position = flag.position - 1
          flag.save
        end
      end

    end

    return true
  end


#  def in_list?
#    if self.db_package_id.nil?
#
#    else
#
#    end
#  end

  def move_higher
    return false if self.position == 1

    higher = self.higher_item
    tmp = higher.position

    Flag.transaction do
      higher.position = self.position
      self.position = tmp
      higher.save
      self.save
    end

    return true
  end


  def move_lower

    lower = self.lower_item
    return false unless lower
    tmp = lower.position

    Flag.transaction do
      lower.position = self.position
      self.position = tmp
      lower.save
      self.save
    end

    return true
  end


  def higher_item
    return false if self.position == 1

    #find list item with the next lower position (self.pos - 1)
    item = Flag.find_by_type_and_db_project_id_and_db_package_id_and_position(self.class.to_s, self.db_project_id, self.db_package_id, self.position - 1)
    return item
  end


  def lower_item
    #find list item with the next higher position (self.pos + 1)
    item = Flag.find_by_type_and_db_project_id_and_db_package_id_and_position(self.class.to_s, self.db_project_id, self.db_package_id, self.position + 1)

    return item unless item.nil?
    return false
  end

  # returns true when flag is relevant for the given repo/arch combination
  def is_relevant_for?(in_repo, in_arch)
    arch = architecture ? architecture.name : nil

    if arch.nil? and repo.nil?
      return true
    elsif arch.nil? and not repo.nil?
      return true if in_repo == repo
    elsif not arch.nil? and repo.nil?
      return true if in_arch == arch
    else
      return true if in_arch == arch and in_repo == repo
    end

    return false
  end

  def state
    (status+"d").to_sym
  end

  class << self
    def default_state(state=nil)
      if state
        @@default_state = state
      end
      @@default_state
    end
  end


  protected
  def validate
    errors.add("name", "Please set either project_id or package_id.") unless self.db_project_id.nil? or self.db_package_id.nil?
  end


  def before_create
    unless self.db_package_id.nil? and self.db_project_id.nil?
      set_position
    end
  end


  def before_update
    if self.position.nil?
      set_position
    end
  end

  private
  def set_position
    if self.db_package_id.nil?
      self.position = self.db_project.send(self.class.to_s.underscore.pluralize).size + 1
    else
      self.position = self.db_package.send(self.class.to_s.underscore.pluralize).size + 1
    end
    #Warning: The position will not be updated atm. Please delete flags,
    #starting at the end of the lis
  end

end
