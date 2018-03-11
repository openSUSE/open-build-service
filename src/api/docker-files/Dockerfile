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

# Now do the rest as the user with the same ID as the user who
# builds this container
USER frontend
WORKDIR /obs/src/api

# Install/Refresh our gems and start OBS
CMD bundle install --clean && foreman start -f Procfile
