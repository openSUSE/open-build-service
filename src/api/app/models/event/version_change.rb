module Event
  class VersionChange < Base
    include EventObjectPackage

    after_create :create_local_package_version

    self.message_bus_routing_key = 'package.version_change'
    self.description = 'Package changed its version'
    payload_keys :project, :package, :sender, :comment, :requestid, :files, :rev, :newversion, :user, :oldversion

    def set_payload(attribs, keys)
      attribs['comment'] = attribs['comment'][0..800] if attribs['comment'].present?
      attribs['files'] = attribs['files'][0..800] if attribs['files'].present?
      super
    end

    def create_local_package_version
      return unless (package = Package.find_by_project_and_name(payload['project'], payload['package']))
      return unless (attribute_anitya_distribution = AttribType.find_by_namespace_and_name('OBS', 'AnityaDistribution'))
      return if package.project.attribs.find_by_attrib_type_id(attribute_anitya_distribution.id).blank? && package.attribs.find_by_attrib_type_id(attribute_anitya_distribution.id).blank?

      CreateLocalPackageVersionJob.perform_later(package.id, payload['newversion'])
    end
  end
end

# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  eventtype   :string(255)      not null, indexed
#  mails_sent  :boolean          default(FALSE), indexed
#  payload     :text(16777215)
#  undone_jobs :integer          default(0)
#  created_at  :datetime         indexed
#  updated_at  :datetime
#
# Indexes
#
#  index_events_on_created_at  (created_at)
#  index_events_on_eventtype   (eventtype)
#  index_events_on_mails_sent  (mails_sent)
#
