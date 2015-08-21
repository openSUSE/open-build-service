# Validator for Attrib
class AttribIssueValidator < ActiveModel::Validator
  def validate(record)
    if record.attrib_type && !record.attrib_type.issue_list and record.issues.any?
      record.errors[:issues] << "can't have issues"
    end
  end
end
