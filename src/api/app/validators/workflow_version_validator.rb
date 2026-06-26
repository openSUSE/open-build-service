class WorkflowVersionValidator < ActiveModel::Validator
  def validate(record)
    # For now we don't enforce a version number in the workflow yaml
    return if record.workflow_version_number.blank?

    begin
      Gem::Version.new(record.workflow_version_number)
    rescue ArgumentError
      record.errors.add(:base, "Malformed workflow version string, please provide the version number in the format: 'major.minor' e.g. '1.1'")
    end
  end
end
