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
    old_entry = {}
    BinaryRelease.transaction do
      BinaryRelease.where(repository: repository, obsolete_time: nil, modify_time: nil).find_each do |binary|
        key = hashkey_old_binary_releases(binary.as_json)
        # this is on purpose not the entire object to reduce memory requirement
        old_entry[key] = { disturl: binary.binary_disturl,
                           supportstatus: binary.binary_supportstatus,
                           binaryid: binary.binary_id,
                           buildtime: binary.binary_buildtime,
                           id: binary.id }
      end

      processed_item = {}

      # when we have a medium providing further entries
      medium_hash = {}

      new_binary_releases.each do |backend_binary|
        # identifier
        binary_release = { binary_name: backend_binary['name'],
                           binary_version: backend_binary['version'] || 0, # docker containers have no version
                           binary_release: backend_binary['release'] || 0,
                           binary_epoch: backend_binary['epoch'],
                           binary_arch: backend_binary['binaryarch'],
                           medium: backend_binary['medium'],
                           on_medium: medium_hash[backend_binary['medium']],
                           obsolete_time: nil,
                           modify_time: nil }

        # getting activerecord object from hash, dup to unfreeze it
        existing_entry = old_entry[hashkey_new_binary_releases(backend_binary, backend_binary['medium'])]
        if existing_entry
          # still exists, do not touch obsolete time
          processed_item[existing_entry[:id]] = true
          if old_and_new_binary_identical?(existing_entry, backend_binary)
            # but collect the media
            medium_hash[backend_binary['ismedium']] = BinaryRelease.find(existing_entry[:id])  if backend_binary['ismedium'].present?
            next
          end
          # We need to load the entry object for modification
          db_entry = BinaryRelease.find(existing_entry[:id])
          # same binary name and location, but updated content or meta data
          db_entry.modify_time = time
          db_entry.save!
          binary_release[:operation] = 'modified' # new entry will get "modified" instead of "added"
        end

        # complete hash for new entry
        binary_release[:binary_releasetime] = time
        binary_release[:binary_id] = backend_binary['binaryid'] if backend_binary['binaryid'].present?
        binary_release[:binary_buildtime] = nil
        binary_release[:binary_buildtime] = Time.strptime(backend_binary['buildtime'].to_s, '%s') if backend_binary['buildtime'].present?
        binary_release[:binary_disturl] = backend_binary['disturl']
        binary_release[:binary_supportstatus] = backend_binary['supportstatus']
        binary_release[:binary_cpeid] = backend_binary['cpeid']
        if backend_binary['updateinfoid']
          binary_release[:binary_updateinfo] = backend_binary['updateinfoid']
          binary_release[:binary_updateinfo_version] = backend_binary['updateinfoversion']
        end
        if backend_binary['project'].present? && backend_binary['package'].present?
          # the package may be missing if the binary comes via DoD
          source_package = Package.striping_multibuild_suffix(backend_binary['package'])
          rp = Package.find_by_project_and_name(backend_binary['project'], source_package)
          if source_package.include?(':') && !source_package.start_with?('_product:')
            flavor_name = backend_binary['package'].gsub(/^#{source_package}:/, '')
            binary_release[:flavor] = flavor_name
          end
          binary_release[:release_package_id] = rp.id if backend_binary['project'] && rp
        end
        if backend_binary['patchinforef']
          begin
            patchinfo = Patchinfo.new(data: Backend::Api::Sources::Project.patchinfo(backend_binary['patchinforef']))
          rescue Backend::NotFoundError
            # patchinfo disappeared meanwhile
          end
          binary_release[:binary_maintainer] = patchinfo.hashed['packager'] if patchinfo && patchinfo.hashed['packager']
        end

        # put a reference to the medium aka container
        binary_release[:on_medium] = medium_hash[backend_binary['medium']] if backend_binary['medium'].present?

        # new entry, also for modified binaries.
        new_binary_release = repository.binary_releases.create(binary_release)
        processed_item[new_binary_release.id] = true

        # store in medium case
        medium_hash[backend_binary['ismedium']] = new_binary_release if backend_binary['ismedium'].present?
      end

      # and mark all not processed binaries as removed
      BinaryRelease.where(repository: repository, obsolete_time: nil, modify_time: nil).where.not(id: processed_item.keys).update_all(obsolete_time: time)
    end
  end

  def hashkey_old_binary_releases(binary)
    "#{binary['binary_name']}|#{binary['binary_version'] || '0'}|#{binary['binary_release'] || '0'}|#{binary['binary_epoch'] || '0'}|#{binary['binary_arch'] || ''}|#{binary['medium'] || ''}"
  end

  def hashkey_new_binary_releases(binary, medium)
    "#{binary['name']}|#{binary['version'] || '0'}|#{binary['release'] || '0'}|#{binary['epoch'] || '0'}|#{binary['binaryarch'] || ''}|#{medium || ''}"
  end

  def old_and_new_binary_identical?(existing_entry, candidate)
    # We ignore not set binary_id in db because it got introduced later
    # we must not touch the modification time in that case
    existing_entry[:disturl] == candidate['disturl'] &&
      existing_entry[:supportstatus] == candidate['supportstatus'] &&
      (existing_entry[:binaryid].nil? || existing_entry[:binaryid] == candidate['binaryid']) &&
      existing_entry[:buildtime] == binary_hash_build_time(candidate)
  end

  def binary_hash_build_time(binary_hash)
    # handle nil/NULL case
    return if binary_hash['buildtime'].blank?

    Time.strptime(binary_hash['buildtime'].to_s, '%s')
  end
end
