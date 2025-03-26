# This is just a thin layer on top of the frontend container
# that makes sure different users can run it without the
# contained rails app generating files in the git checkout with
# some strange user...

FROM registry.opensuse.org/obs/server/unstable/containers/containers/openbuildservice/frontend-features:latest
ARG CONTAINER_USERID

# for lint task
RUN npm install -g jshint
# Same brakeman version is pinned in our CI configuration to have reproducible builds (the license forbids us from shipping the gem in our appliance)
RUN gem install --no-format-executable brakeman --version 5.4.0

# Configure our user
RUN usermod -u $CONTAINER_USERID frontend

# Making the directory our bundle is installed writable
RUN chown frontend:users /usr/lib64/obs-api

# We copy the Gemfiles into this intermediate build stage so it's checksum
# changes and all the subsequent stages (a.k.a. the bundle install call below)
# have to be rebuild. Otherwise, after the first build of this image,
# docker would use it's cache for this and the following stages.
ADD Gemfile /obs/src/api/Gemfile
ADD Gemfile.lock /obs/src/api/Gemfile.lock
RUN chown -R frontend /obs/src/api

# Now do the rest as the user with the same ID as the user who
# builds this container
USER frontend
WORKDIR /obs/src/api

# Configure our bundle
RUN bundle config build.ffi --enable-system-libffi; \
    bundle config build.nokogiri --use-system-libraries; \
    bundle config build.sassc --disable-march-tune-native; \
    bundle config build.nio4r --with-cflags='-Wno-return-type'

# Refresh our bundle
RUN bundle install --jobs=3 --retry=3

# Run our command
CMD ["foreman", "start", "-f", "Procfile"]
