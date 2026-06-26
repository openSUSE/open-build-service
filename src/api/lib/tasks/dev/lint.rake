namespace :dev do
  namespace :lint do
    # Run this task with: rails dev:lint:all
    desc 'Run all linters we use'
    task :all do
      Rake::Task['dev:lint:database_consistency'].invoke
      Rake::Task['dev:lint:rubocop:all'].invoke
      Rake::Task['dev:lint:haml'].invoke
      Rake::Task['dev:lint:js'].invoke
    end

    desc 'Run the database_consistency linter'
    task :database_consistency do
      puts "\nRunning database_consistency in src/api...\n"
      sh 'database_consistency -c .database_consistency.todo.yml'
    end

    desc 'Run the haml linter'
    task :haml do
      puts "\nRunning haml-lint in src/api..."
      Rake::Task['haml_lint'].invoke('--parallel')
    end

    desc 'Run apidocs linter'
    task :apidocs do
      sh 'find public/apidocs -name  \'*.yaml\' | xargs -P8 -I % ruby -e "require \'yaml\'; YAML.load_file(\'%\',  permitted_classes: [Time])"'
    end

    desc 'Run JavaScript linter'
    task :js do
      puts "\nRunning jshint in src/api..."
      sh 'jshint ./app/assets/javascripts/'
    end

    namespace :rubocop do
      desc 'Run the ruby linter in rails and in root'
      task all: %i[root rails]

      desc 'Run the ruby linter in rails'
      task :rails do
        puts "\nRunning rubocop in src/api..."
        sh 'rubocop', '--fail-fast', '--display-style-guide', '--fail-level', 'convention', '--ignore_parent_exclusion'
      end

      desc 'Run the ruby linter in root'
      task :root do
        Dir.chdir('../..') do
          puts "\nRunning rubocop in the root directory..."
          sh 'rubocop', '--fail-fast', '--display-style-guide', '--fail-level', 'convention'
        end
      end

      namespace :auto_gen_config do
        desc 'Autogenerate rubocop config in rails and in root'
        task all: %i[root rails]

        desc 'Autogenerate rubocop config in rails'
        task :rails do
          # We set `exclude-limit` to 100 (from the default of 15) to make it easier to tackle TODOs one file at a time
          # A cop will be disabled only if it triggered offenses for more than 100 files
          sh 'rubocop --auto-gen-config --ignore_parent_exclusion --auto-gen-only-exclude --exclude-limit 100'
        end

        desc 'Autogenerate rubocop config in root'
        task :root do
          Dir.chdir('../..') do
            # We set `exclude-limit` to 100 (from the default of 15) to make it easier to tackle TODOs one file at a time
            # A cop will be disabled only if it triggered offenses for more than 100 files
            sh 'rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 100'
          end
        end
      end

      desc 'Autocorrect rubocop offenses in rails and in root'
      task :autocorrect do
        sh 'rubocop --autocorrect --ignore_parent_exclusion'
        Dir.chdir('../..') do
          sh 'rubocop --autocorrect'
        end
      end
    end
  end
end
