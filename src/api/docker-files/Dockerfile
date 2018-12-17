# This is just a thin layer on top of the frontend container
# that makes sure different users can run it without the
# contained rails app generating files in the git checkout with
# some strange user...

FROM openbuildservice/frontend-base
ARG CONTAINER_USERID

# Configure our user
RUN usermod -u $CONTAINER_USERID frontend

# We copy the Gemfiles into this intermediate build stage so it's checksum
# changes and all the subsequent stages (a.k.a. the bundle install call below)
# have to be rebuild. Otherwise, after the first build of this image,
# docker would use it's cache for this and the following stages.
ADD Gemfile /obs/src/api/Gemfile
ADD Gemfile.lock /obs/src/api/Gemfile.lock
RUN chown -R frontend /obs/src/api

# we only care for updates in this one repo
RUN zypper -n refresh 'OBS_Server_Unstable'
RUN zypper --no-refresh -n in obs-bundled-gems ruby2.5-rubygem-rack ruby2.5-rubygem-rake

# Now do the rest as the user with the same ID as the user who
# builds this container
USER frontend
WORKDIR /obs/src/api

# Refresh our bundle
RUN export NOKOGIRI_USE_SYSTEM_LIBRARIES=1; sudo bundle install --path /usr/lib64/obs-api --jobs=3 --retry=3

# Run our command
CMD ["foreman", "start", "-f", "Procfile"]
