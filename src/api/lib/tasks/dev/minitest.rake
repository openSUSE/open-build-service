namespace :dev do
  namespace :minitest do
    namespace :fixtures do
      desc 'Create minitest fixtures in the database (as opposed to loading them with db:fixture:load)'
      task create: :test_environment do
        puts "\n\nMake sure you start with a fresh backend! Outside the container run..."
        puts "docker compose stop backend; docker compose rm -f backend; docker compose up -d backend\n\n"
        puts 'Please also note this will drop your current test database'
        puts "Confirm? Enter 'YES' to confirm:"
        input = $stdin.gets.chomp
        raise "Aborting... You entered: #{input} not YES" unless input == 'YES'

        Rake::Task['db:drop'].invoke
        Rake::Task['db:setup'].invoke
        Rake::Task['db:fixtures:load'].invoke
        # Enable writing to the backend
        CONFIG['global_write_through'] = true
        # Login default admin for syncing projects/packages to the backend
        User.session = User.default_admin
        # Rewrite interconnect url
        Project.where(remoteurl: 'http://localhost:3200').map { |project| project.update!(remoteurl: 'http://backend:5352') }
        # Sync all projects to the backend
        Project.all.map(&:store)
        # Sync all packages to the backend
        # FIXME: Why do we have `_product:fixed-release` in the fixtures if you can't even store it?
        Package.where.not(name: '_product:fixed-release').map(&:store)
      end
    end
  end
end
