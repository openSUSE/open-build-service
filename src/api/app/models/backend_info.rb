# just key:value for things to be stored about the running backend
# and that are not configuration
class BackendInfo < ActiveRecord::Base

  def self.set_value(key, value)
    v = BackendInfo.find_or_initialize_by(key: key)
    v.value = value
    v.save!
  end

  def self.lastevents_nr=(nr)
    self.set_value('lastevents_nr', nr.to_s)
  end

  def self.lastnotification_nr=(nr)
    self.set_value('lastnotification_nr', nr.to_s)
  end

  def self.get_value(key)
    BackendInfo.where(key: key).pluck(:value)
  end

  def self.get_integer(key)
    nr = self.get_value(key)
    return 0 if nr.empty?
    Integer(nr[0])
  end

  def self.lastevents_nr
    self.get_integer('lastevents_nr')
  end

  def self.lastnotification_nr
    self.get_integer('lastnotification_nr')
  end

  # long running task - if we're out of sync with backend
  def scan_all_links
    start_time = Time.now
    names = Package.distinct(:name).order(:name).pluck(:name)
    while !names.empty? do
      slice = names.slice!(0, 30)
      path = "/search/package/id?match=("
      path += slice.map { |name| "linkinfo/@package='#{CGI.escape(name)}'" }.join("+or+")
      path += ")"
      answer = Xmlhash.parse(Suse::Backend.get(path).body)
      answer.elements('package') do |p|
        pkg = Package.find_by_project_and_name(p['project'], p['name'])
        # if there is a linkinfo for a package not in database, there can not be a linked_package either
        next unless pkg
        pkg.update_linkinfo
      end

    end
    # every link we haven't seen in this loop, is no link anymore
    LinkedPackage.where("updated_at < ?", start_time).delete_all
  end

  def update_last_events
    # pick first admin so we can see all projects - as this function is called from delayed job
    # TODO: add an admin user without password exactly for delayed_jobs?
    User.current ||= User.get_default_admin

    # it's possible that we see the same event more often but the
    # alternative is waiting for the *next* event, which would
    # make this function hang for 15 minutes and we want to call
    # it often
    event = BackendInfo.lastevents_nr
    lastevents = Xmlhash.parse(Suse::Backend.get("/lastevents?start=#{event}").body)

    if lastevents['sync'] == 'lost'
      # we're doomed!
      BackendInfo.lastevents_nr = Integer(lastevents['next']) - 1
      BackendInfo.first.scan_all_links
      return
    end

    lastevents.elements('event') do |e|
      next if e['type'] != 'package'
      pkg = Package.find_by_project_and_name(e['project'], e['package'])
      next unless pkg
      pkg.update_linkinfo
    end
    BackendInfo.lastevents_nr = Integer(lastevents['next']) - 1
  end

end
