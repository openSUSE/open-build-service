DBQueryMatchers.configure do |config|
  config.ignores = [
    # Executed multiple times when fetching something in the configuration
    /^SELECT `configurations`.* FROM `configurations`/,
    # Executed by the schema cache
    /^SHOW FULL FIELDS FROM/,
    # TODO: Explain this
    /^SELECT column_name\nFROM information_schema.statistics/,
    # Executed when there is a transaction
    /^SAVEPOINT active_record/,
    # Executed when there is a transaction
    /^RELEASE SAVEPOINT active_record/
  ]
  config.ignore_cached = true
end
