# This is just a thin layer on top of the frontend container
# that makes sure different users can run it without the
# contained rails app generating files in the git checkout with
# some strange user...

FROM registry.opensuse.org/obs/server/unstable/containers/containers/openbuildservice/frontend-features:latest
ARG CONTAINER_USERID

# for javascript linting
RUN npm install -g jshint
# brakeman: license does not allow shipping, so it can't be in our bundle. Sync version with .github/workflows/brakeman.yml
# next_rails: To be able to call `next` the gem is also needed to be installed outside the bundle
# foreman: https://github.com/ddollar/foreman/wiki/Don't-Bundle-Foreman
RUN gem install --no-format-executable brakeman:7.1.1 next_rails foreman

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
