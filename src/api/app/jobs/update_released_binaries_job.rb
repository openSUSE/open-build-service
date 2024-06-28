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
    # We record BinaryRelease attributes in this hash of hashes to be able to compare them later on.
    # This is an optimization so we do not have to fetch BinaryRelease individually from the database.
    # FIXME: This is exactly what ActiveRecord::Associations::CollectionProxy does no?
    old_binary_releases = {}

    # We record all the BinaryRelease we process in this method to mark all but the current_binary_releases
    # as "obsolete" at the end.
    current_binary_releases = {}

    # The Backend expresses the association between BinaryRelease via medium/ismedium:
    #   - A BinaryRelease on a medium has the attribute `medium: 'openSUSE_Leap'`.
    #   - A BinaryRelease that is a medium has the attribute `ismedium: 'openSUSE_Leap'`.
    # We use this hash to build the BinaryRelease.on_medium relationship from the backend data
    medium_hash = {}

    # FIXME: This job is the only thing that ever changes the BinaryRelease table. It runs in it's own queue
    #        with one worker. Only one UpdateReleasedBinariesJob will run at once. Why do we need this transaction?
    BinaryRelease.transaction do
      # Populate the old_binary_releases hash
      repository.binary_releases.current.unchanged.find_each do |binary|
        key = hashkey_binary_release(binary)
        old_binary_releases[key] = binary.slice(:disturl, :supportstatus, :binaryid, :buildtime, :id)
      end

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
        # FIXME: This could also happen in the database instead...
        new_binary_release.version = backend_binary['version'] || 0 # e.g. docker containers have no version
        new_binary_release.release = backend_binary['release'] || 0

        old_binary_release = old_binary_releases[hashkey_binary_release(backend_binary)]
        if old_binary_release
          # Fetch the full record from the database
          old_binary_release = repository.binary_releases.find(old_binary_release[:id])
          current_binary_releases[old_binary_release.id] = true
          # If the BinaryRelease is unchanged we leave it be
          if old_and_new_binary_identical?(old_binary_release, new_binary_release)
            # Populate the medium_hash
            medium_hash[backend_binary['ismedium']] = old_binary_release.id if backend_binary['ismedium'].present?
            next
          end
          # Set modify_time to whenever the Event::Packtrack happened that triggered this job
          old_binary_release.update_columns(modify_time: time)
          # We are still going to create a new BinaryRelease with updated attributes that "replaces" old_binary_release
          new_binary_release.operation = 'modified'
        end

        if backend_binary['project'].present? && backend_binary['package'].present?
          new_binary_release.flavor = Package.multibuild_flavor(backend_binary['package'])
          package_name = Package.striping_multibuild_suffix(backend_binary['package'])
          new_binary_release.release_package_id = Package.find_by_project_and_name(backend_binary['project'], package_name)&.id
        end

        new_binary_release.binary_maintainer = get_maintainer_from_patchinfo(backend_binary['patchinforef']) if backend_binary['patchinforef']

        new_binary_release.on_medium_id = medium_hash[backend_binary['medium']] if backend_binary['medium'].present?

        new_binary_release.save
        current_binary_releases[new_binary_release.id] = true

        # populate the medium_hash
        medium_hash[backend_binary['ismedium']] = new_binary_release.id if backend_binary['ismedium'].present?
      end

      # and mark all but the current BinaryRelease as obsolete
      repository.binary_releases.current.unchanged.where.not(id: current_binary_releases.keys).update_all(obsolete_time: time)
    end
  end

  def hashkey_binary_release(binary)
    "#{binary['name']}|#{binary['version'] || '0'}|#{binary['release'] || '0'}|#{binary['epoch'] || '0'}|#{binary['binaryarch'] || ''}|#{binary['medium'] || ''}"
  end

  def old_and_new_binary_identical?(old_binary, new_binary)
    # We ignore not set binary_id in db because it got introduced later
    # we must not touch the modification time in that case
    old_binary.disturl == new_binary.disturl &&
      old_binary.supportstatus == new_binary.supportstatus &&
      (old_binary.binaryid.nil? || old_binary.binaryid == new_binary.binaryid) &&
      old_binary.buildtime == new_binary.buildtime
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
