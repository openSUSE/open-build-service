module PackageScmsync
  extend ActiveSupport::Concern

  def scmsynced?
    scmsync.present? || project.scmsync.present?
  end
end
