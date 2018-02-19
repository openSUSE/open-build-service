FROM openbuildservice/base

RUN /root/bin/docker-bootstrap.sh backend

# Add our configurations
ADD docker-files/configurations.tar.bz2 /

# Run our command
WORKDIR /obs
CMD ["contrib/start_development_backend", "-d", "/obs"]
