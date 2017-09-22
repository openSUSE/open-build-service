FROM openbuildservice/base
ARG CONTAINER_USERID

# FIXME: https://bugzilla.opensuse.org/show_bug.cgi?id=957818
RUN rm -rf /var/cache/zypp/*

# Install requirements for the frontend 
RUN zypper -n install --no-recommends --replacefiles \
  # as search daemon
  sphinx \
  # for testing javascript driven pages
  phantomjs \
  nodejs \
  # for accessing the database
  mariadb-client \
  # for rspec (it does something with git)
  git-core \
  # dependencies for building gems
  ruby2.4-devel cyrus-sasl-devel openldap2-devel libxml2-devel zlib-devel libxslt-devel \
  # gems we don't want to build
  ruby2.4-rubygem-mysql2 \
  # gems we use that are not in our bundle
  ruby2.4-rubygem-bundler ruby2.4-rubygem-thor-0_19 ruby2.4-rubygem-foreman

# Configure our user
RUN usermod -u $CONTAINER_USERID frontend

USER frontend
WORKDIR /obs/src/api

RUN ln -sf /usr/bin/ruby.ruby2.4 /home/frontend/bin/ruby

ADD src/api/Gemfile /obs/src/api/Gemfile
ADD src/api/Gemfile.lock /obs/src/api/Gemfile.lock
# Setup bundle
RUN bundle config build.nokogiri --use-system-libraries; bundle install

# Run our command
CMD ["foreman", "start", "-f", "Procfile"] 
