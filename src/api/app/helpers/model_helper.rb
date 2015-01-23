module ModelHelper

  # this method is used in models to sync xml hash lists with the database entries
  # the class needs to define the keys which identifies an entry in the list via an
  # array delivered by the self._sync_keys method
  #
  # these entries will be added or removed
  #
  # further key/values in the hash will be updated in matching entries
  #
  def sync_hash_with_model(entry_class, dblist, inhasharray)

    keys = entry_class._sync_keys
    oldentries = {}

    dblist.each do |e|
      key = ""
      keys.each{|k| key << "#{e.send(k).to_s}::"}
      oldentries[key]=e
    end

    entry_class.transaction do
      inhasharray.each do |hash|
        key = ""
        keys.each do |k|
          raise 'MissingKey', k unless hash.has_key? k
          key << "#{hash[k].to_s}::"
        end
        if oldentries[key]
          # exists, do we need to update it?
          modified=nil
          hash.each do |entry|
            next if keys.include? entry.first
            if entry.last != oldentries[key][entry.first]
              oldentries[key][entry.first] = entry.last
              modified=true
            end
          end
          oldentries[key].save if modified
          oldentries.delete(key)
        else
          # not existing yet, creating
          dblist.create(hash)
        end
      end
      # delete obsolete entries
      dblist.delete(oldentries.values)
    end
  end

end
