FROM openbuildservice/base

# Install memcached
RUN /root/bin/docker-bootstrap.sh memcached

CMD ["/usr/sbin/memcached", "-u", "memcached"]
