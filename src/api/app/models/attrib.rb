# Attribute container inside package meta data
# Attribute definitions are inside attrib_type

class Attrib < ActiveRecord::Base
  belongs_to :package
  belongs_to :project
  belongs_to :attrib_type
  has_many :issues, class_name: 'AttribIssue', dependent: :destroy
  has_many :values, -> { order("position") }, class_name: 'AttribValue', dependent: :delete_all

  scope :nobinary, -> { where(:binary => nil) }

  def cachekey
    if binary
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}|#{binary}"
    else
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    end
  end

  def update(values = [], issues = [])
    save = false
    #--- update issues ---#
    issuecache = Hash.new
    self.issues.each do |ai|
      issuecache[ai.issue.id] = ai
    end

    issues.each do |issue|
      unless issuecache.has_key? issue.id
        self.save! unless self.id
        self.issues << AttribIssue.new(:issue_id => issue.id)
        save = true
      end
      # do no remove
      issuecache.delete(issue.id)
    end

    # delete old entries
    issuecache.each do |k, ai|
      ai.delete
      save = true
    end

    #--- update values ---#
    current_values = self.values.map { |v| v.value}

    if values != current_values
      save = true
      logger.debug "--- updating values ---"
      self.values.delete_all
      position = 1
      values.each do |val|
        self.values.build(value: val, position: position)
        position += 1
      end
    end

    self.save! if save

    return save
  end

end
