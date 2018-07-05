FROM opensuse:42.3

# Add our repo
RUN echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf; \
    zypper ar -f http://download.opensuse.org/repositories/OBS:/Server:/Unstable/openSUSE_42.3/OBS:Server:Unstable.repo; \
    zypper ar -f http://download.opensuse.org/repositories/openSUSE:/Tools/openSUSE_42.3/openSUSE:Tools.repo; \
    zypper --gpg-auto-import-keys refresh

# Install requirements for all our containers
RUN zypper -n install --no-recommends --replacefiles \
  make gcc gcc-c++ patch curl vim vim-data psmisc \
  timezone ack glibc-locale sudo aaa_base hostname

# Add our bootstrap script
ADD docker-bootstrap.sh /root/bin/docker-bootstrap.sh

# Add our user
RUN useradd -m frontend

# Setup sudo
RUN echo 'frontend ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Run our command
CMD ["bash", "-l"]
