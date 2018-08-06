# layer on top to include backend for minitest

FROM openbuildservice/frontend

# fix file conflict
RUN sudo zypper -n remove hostname
RUN sudo zypper -n install net-tools inst-source-utils obs-server obs-signd obs-service-download_src_package obs-service-download_files \
    obs-service-download_url obs-service-format_spec_file obs-service-kiwi_import perl-Devel-Cover perl-Diff-LibXDiff osc

WORKDIR /obs/src/api
CMD ["/bin/bash", "-l"]


