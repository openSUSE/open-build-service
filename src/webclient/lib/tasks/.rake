#needed for testing without database. It prevents rake to run the db:test:prepare task.
Rake::Task[:'test:units'].prerequisites.clear

