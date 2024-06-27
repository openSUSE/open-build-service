# Every time an Event::PackTrack happens this adds a new "set" of BinaryRelease to a Repository
class UpdateReleasedBinariesJob < CreateJob
  queue_as :releasetracking

  def perform(event_id)
    event = Event::Base.find(event_id)

    repository = Repository.find_by_project_and_name(event.payload['project'], event.payload['repo'])
    return unless repository

    begin
      # NOTE: Yes they key to identify the notification on the backend is called payload in the event payload. Can't make this shit up...
      new_binary_releases = ActiveSupport::JSON.decode(Backend::Api::Server.notification_payload(event.payload['payload']))
    rescue Backend::NotFoundError
      logger.error("Payload got removed for #{event.payload['payload']}")
      return
    end
    update_binary_releases_for_repository(repository, new_binary_releases, event.created_at)
    Backend::Api::Server.delete_notification_payload(event.payload['payload'])
  end

  private

  # repository: a Repository instance
  # new_binary_releases: An Array of Hashes of BinaryRelease attributes
  #
  # This method compares the set of existing BinaryRelease (repository.binary_releases)
  # with the set of new BinaryRelease (new_binary_releases) and...
  #
  # - If the BinaryRelease from new_binary_releases does not exist for Repository:
  #   - it creates a new BinaryRelease
  # - If the BinaryRelease from new_binary_releases exists for Repository:
  #   - sets the existing BinaryRelease.modify_time
  #   - creates a new BinaryRelease with updated attributes and the attribute operation set to modified
  # - If the BinaryRelease exists for the Repository but it's not in new_binary_releases:
  #   - sets BinaryRelease.obsolete_time
  #
  def update_binary_releases_for_repository(repository, new_binary_releases, time = Time.now)
    # building a hash to avoid single SQL select calls slowing us down too much
    old_binary_releases = {}
    BinaryRelease.transaction do
      repository.binary_releases.current.unchanged.find_each do |binary|
        key = hashkey_binary_release(binary)
        old_binary_releases[key] = binary.slice(:disturl, :supportstatus, :binaryid, :buildtime, :id)
      end

      processed_item = {}

      # when we have a medium providing further entries
      medium_hash = {}

      new_binary_releases.each do |backend_binary|
        backend_binary = backend_binary.with_indifferent_access
        new_binary_release = repository.binary_releases.new(backend_binary.slice(:name, :binaryid, :binaryarch,
                                                                                 :version, :release, :epoch,
                                                                                 :medium, :cpeid,
                                                                                 :disturl, :supportstatus,
                                                                                 :updateinfoid, :updateinfoversion))

        # `BinaryRelease`` expects a `DateTime` as attribute, the backend gives us epoch
        new_binary_release.buildtime = Time.zone.at(backend_binary['buildtime'].to_i) if backend_binary['buildtime'].present?

        # Set releasetime to whenever the Event::Packtrack happened that triggered this job
        new_binary_release.binary_releasetime = time

        # Set defaults for versions/release
        new_binary_release.version = backend_binary['version'] || 0 # e.g. docker containers have no version
        new_binary_release.release = backend_binary['release'] || 0

        # getting activerecord object from hash, dup to unfreeze it
        old_binary_release = old_binary_releases[hashkey_binary_release(backend_binary)]
        if old_binary_release
          # still exists, do not touch obsolete time
          old_binary_release = repository.binary_releases.find(old_binary_release[:id])
          processed_item[old_binary_release.id] = true
          if old_and_new_binary_identical?(old_binary_release, backend_binary)
            # but collect the media
            medium_hash[backend_binary['ismedium']] = old_binary_release if backend_binary['ismedium'].present?
            next
          end
          # Set modify_time to whenever the Event::Packtrack happened that triggered this job
          old_binary_release.update_columns(modify_time: time)
          new_binary_release.operation = 'modified' # new entry will get "modified" instead of "added"
        end

        if backend_binary['project'].present? && backend_binary['package'].present?
          new_binary_release.flavor = Package.multibuild_flavor(backend_binary['package'])
          package_name = Package.striping_multibuild_suffix(backend_binary['package'])
          new_binary_release.release_package_id = Package.find_by_project_and_name(backend_binary['project'], package_name)&.id
        end

        new_binary_release.binary_maintainer = get_maintainer_from_patchinfo(backend_binary['patchinforef']) if backend_binary['patchinforef']

        # put a reference to the medium aka container
        new_binary_release.on_medium = medium_hash[backend_binary['medium']] if backend_binary['medium'].present?

        # new entry, also for modified binaries.
        new_binary_release.save
        processed_item[new_binary_release.id] = true

        # store in medium case
        medium_hash[backend_binary['ismedium']] = new_binary_release if backend_binary['ismedium'].present?
      end

      # and mark all not processed binaries as removed
      repository.binary_releases.current.unchanged.where.not(id: processed_item.keys).update_all(obsolete_time: time)
    end
  end

  def hashkey_binary_release(binary)
    "#{binary['name']}|#{binary['version'] || '0'}|#{binary['release'] || '0'}|#{binary['epoch'] || '0'}|#{binary['binaryarch'] || ''}|#{binary['medium'] || ''}"
  end

  def old_and_new_binary_identical?(old_binary, new_binary)
    # We ignore not set binary_id in db because it got introduced later
    # we must not touch the modification time in that case
    old_binary.disturl == new_binary['disturl'] &&
      old_binary.supportstatus == new_binary['supportstatus'] &&
      (old_binary.binaryid.nil? || old_binary.binaryid == new_binary['binaryid']) &&
      old_binary.buildtime.to_i == new_binary['buildtime'].to_i
  end

  def get_maintainer_from_patchinfo(patchinforef)
    begin
      patchinfo = Patchinfo.new(data: Backend::Api::Sources::Project.patchinfo(patchinforef))
    rescue Backend::NotFoundError
      # patchinfo disappeared meanwhile
    end
    patchinfo.hashed['packager'] if patchinfo
  end
end
