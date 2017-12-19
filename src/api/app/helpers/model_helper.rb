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
    entries = {}

    dblist.each do |e|
      key = ''
      keys.each { |k| key << "#{e.send(k)}::" }
      entries[key] = e
    end
    to_delete = entries.clone

    entry_class.transaction do
      inhasharray.each do |hash|
        key = ''
        keys.each do |k|
          raise 'MissingKey', k unless hash.key? k
          key << "#{hash[k]}::"
        end
        if entries[key]
          # exists, do we need to update it?
          modified = nil
          hash.each do |entry_key, entry_value|
            next if keys.include?(entry_key)
            if entry_value != entries[key][entry_key]
              entries[key][entry_key] = entry_value
              modified = true
            end
          end
          entries[key].save if modified
          to_delete.delete(key)
        else
          # not existing yet, creating
          entries[key] = dblist.create(hash)
        end
      end

      # delete obsolete entries
      dblist.delete(to_delete.values)
    end
  end
end
