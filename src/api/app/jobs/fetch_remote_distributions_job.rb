class FetchRemoteDistributionsJob < ApplicationJob
  def perform
    success = true

    Project.remote.each do |project|
      distributions_xml = Project::RemoteURL.load(project, '/distributions.xml')

      # Project::RemoteURL returns nil (and reports to log/Airbrake) in case of errors.
      # Keep the cached distributions of this remote project and go on with the next one.
      if distributions_xml.nil?
        success = false
        next
      end

      if Xmlhash.parse(distributions_xml).blank?
        Distribution.remote.for_project(project.name).destroy_all
      else
        Suse::Validator.validate('distributions', distributions_xml)
        distributions_xmlhash = Xmlhash.parse(distributions_xml)
        bulk_replace(project: project.name, distributions_xmlhash: distributions_xmlhash)
      end
    end

    success
  end

  private

  def bulk_replace(project:, distributions_xmlhash: Xmlhash.new)
    errors = []
    distributions = []

    distributions_xmlhash.elements('distribution') do |distribution_xmlhash|
      distribution = Distribution.new_from_xmlhash(distribution_xmlhash)
      distribution.project = "#{project}:#{distribution.project}"
      distribution.remote = true
      distributions << distribution
      errors << distributions.errors unless distribution.valid?
    end

    raise errors.map(&:full_messages).to_s if errors.any? || distributions.empty?

    Distribution.remote.for_project(project).destroy_all
    distributions.map(&:save!)
  end
end
