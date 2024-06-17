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

  def update_binary_releases_for_repository(repository, new_binary_releases, time = Time.now)
    # building a hash to avoid single SQL select calls slowing us down too much
    old_binary_releases = {}
    BinaryRelease.transaction do
      BinaryRelease.where(repository: repository, obsolete_time: nil).find_each do |binary|
        key = hashkey_old_binary_releases(binary.as_json)
        old_binary_releases[key] = binary
      end

      processed_item = {}

      # when we have a medium providing further entries
      medium_hash = {}

      new_binary_releases.each do |binary|
        # identifier
        hash = { binary_name: binary['name'],
                 binary_version: binary['version'] || 0, # docker containers have no version
                 binary_release: binary['release'] || 0,
                 binary_epoch: binary['epoch'],
                 binary_arch: binary['binaryarch'],
                 medium: binary['medium'],
                 on_medium: medium_hash[binary['medium']],
                 obsolete_time: nil,
                 modify_time: nil }

        # getting activerecord object from hash, dup to unfreeze it
        entry = old_binary_releases[hashkey_new_binary_releases(binary, binary['medium'])]
        if entry
          # still exists, do not touch obsolete time
          processed_item[entry.id] = true
          if old_and_new_binary_identical?(entry, binary)
            # but collect the media
            medium_hash[binary['ismedium']] = entry if binary['ismedium'].present?
            next
          end
          # same binary name and location, but updated content or meta data
          entry.modify_time = time
          entry.save!
          hash[:operation] = 'modified' # new entry will get "modified" instead of "added"
        end

        # complete hash for new entry
        hash[:binary_releasetime] = time
        hash[:binary_id] = binary['binaryid'] if binary['binaryid'].present?
        hash[:binary_buildtime] = nil
        hash[:binary_buildtime] = Time.strptime(binary['buildtime'].to_s, '%s') if binary['buildtime'].present?
        hash[:binary_disturl] = binary['disturl']
        hash[:binary_supportstatus] = binary['supportstatus']
        hash[:binary_cpeid] = binary['cpeid']
        if binary['updateinfoid']
          hash[:binary_updateinfo] = binary['updateinfoid']
          hash[:binary_updateinfo_version] = binary['updateinfoversion']
        end
        if binary['project'].present? && binary['package'].present?
          # the package may be missing if the binary comes via DoD
          source_package = Package.striping_multibuild_suffix(binary['package'])
          rp = Package.find_by_project_and_name(binary['project'], source_package)
          if source_package.include?(':') && !source_package.start_with?('_product:')
            flavor_name = binary['package'].gsub(/^#{source_package}:/, '')
            hash[:flavor] = flavor_name
          end
          hash[:release_package_id] = rp.id if binary['project'] && rp
        end
        if binary['patchinforef']
          begin
            patchinfo = Patchinfo.new(data: Backend::Api::Sources::Project.patchinfo(binary['patchinforef']))
          rescue Backend::NotFoundError
            # patchinfo disappeared meanwhile
          end
          hash[:binary_maintainer] = patchinfo.hashed['packager'] if patchinfo && patchinfo.hashed['packager']
        end

        # put a reference to the medium aka container
        hash[:on_medium] = medium_hash[binary['medium']] if binary['medium'].present?

        # new entry, also for modified binaries.
        entry = repository.binary_releases.create(hash)
        processed_item[entry.id] = true

        # store in medium case
        medium_hash[binary['ismedium']] = entry if binary['ismedium'].present?
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

  def old_and_new_binary_identical?(old_binary, new_binary)
    # We ignore not set binary_id in db because it got introduced later
    # we must not touch the modification time in that case
    old_binary.binary_disturl == new_binary['disturl'] &&
      old_binary.binary_supportstatus == new_binary['supportstatus'] &&
      (old_binary.binary_id.nil? || old_binary.binary_id == new_binary['binaryid']) &&
      old_binary.binary_buildtime == binary_hash_build_time(new_binary)
  end

  def binary_hash_build_time(binary_hash)
    # handle nil/NULL case
    return if binary_hash['buildtime'].blank?

    Time.strptime(binary_hash['buildtime'].to_s, '%s')
  end
end
