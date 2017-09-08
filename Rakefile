CONTAINER_USERID = %x(id -u)

namespace :docker do
  desc 'Build your development environment'
  task :build do
    sh "docker build . -t openbuildservice/frontend --build-arg CONTAINER_USERID=#{CONTAINER_USERID}"
    sh "contrib/bootstrap.rb"
  end

  desc 'Rebuild our static docker containers'
  task :rebuild do
    sh "docker build . -t openbuildservice/base:423 -t openbuildservice/base -f Dockerfile.423"
    sh "docker build . -t openbuildservice/mariadb:423 -t openbuildservice/mariadb -f Dockerfile.mariadb"
    sh "docker build . -t openbuildservice/memcached:423 -t openbuildservice/memcached -f Dockerfile.memcached"
    sh "docker build . -t openbuildservice/backend:423 -t openbuildservice/backend -f Dockerfile.backend"
  end

  desc 'Publish our docker containers'
  task publish: [:rebuild] do
    sh "docker push openbuildservice/base:423"
    sh "docker push openbuildservice/base"
    sh "docker push openbuildservice/mariadb:423"
    sh "docker push openbuildservice/mariadb"
    sh "docker push openbuildservice/memcached:423"
    sh "docker push openbuildservice/memcached"
    sh "docker push openbuildservice/backend:423"
    sh "docker push openbuildservice/backend"
  end

  namespace :test do
    desc 'Run our frontend tests in the docker container'
    task :frontend do
      begin
        sh "docker-compose up -d db"
        sh "docker-compose run --no-deps --rm frontend bundle exec rake assets:clobber db:create RAILS_ENV=test"
        sh "docker-compose run --no-deps --rm frontend bundle exec rspec"
      ensure
        sh "docker-compose stop"
      end
    end
    desc 'Run our backend tests in the docker container'
    task :backend do
      begin
        sh "docker-compose run --rm -w /obs backend make -C src/backend test"
      ensure
        sh "docker-compose stop"
      end
    end
  end
end
