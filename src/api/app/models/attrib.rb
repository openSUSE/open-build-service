# Attribute container inside package meta data
# Attribute definitions are inside attrib_type

class Attrib < ActiveRecord::Base
  belongs_to :package
  belongs_to :project, foreign_key: :db_project_id
  belongs_to :attrib_type
  has_many :issues, class_name: 'AttribIssue', dependent: :destroy
  has_many :values, -> { order("position") }, class_name: 'AttribValue', dependent: :destroy

  scope :nobinary, -> { where(:binary => nil) }

  def cachekey
    if binary
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}|#{binary}"
    else
      "#{attrib_type.attrib_namespace.name}|#{attrib_type.name}"
    end
  end

  def update_from_xml(node)
    save = false
    #--- update issues ---#
    issuecache = Hash.new
    self.issues.each do |ai|
      issuecache[ai.issue.id] = ai
    end

    node.each_issue do |i|
      issue = Issue.find_or_create_by_name_and_tracker( i.name, i.tracker )
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
    save = update_values = true unless node.each_value.length == self.values.count

    node.each_value.each_with_index do |val, i|
      next if val.text == self.values[i].value
      save = update_values = true
      break
    end unless update_values

    if update_values
      logger.debug "--- updating values ---"
      self.values.delete_all
      position = 1
      node.each_value do |val|
        self.values << AttribValue.new(:value => val.text, :position => position)
        position += 1
      end
    end

    self.save! if save

    return save
  end

end
