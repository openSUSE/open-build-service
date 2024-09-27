class FetchRemoteDistributionsJob < ApplicationJob
  def perform
    Project.remote.each do |project|
      distributions_xml = Project::RemoteURL.load(project, '/distributions.xml')

      # don't let broken remote instances break us
      if Xmlhash.parse(distributions_xml.to_s).blank?
        Distribution.remote.for_project(project.name).destroy_all
      else
        Suse::Validator.validate('distributions', distributions_xml)
        distributions_xmlhash = Xmlhash.parse(distributions_xml)
        bulk_replace(project: project.name, distributions_xmlhash: distributions_xmlhash)
      end
    end
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
