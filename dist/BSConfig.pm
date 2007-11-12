package BSConfig;

# configured to run on your localhost only
our $srcserver = 'http://localhost:6362';
our $reposerver = 'http://localhost:6262';

# Package defaults
our $bsdir = '/srv/obs';
our $bsuser = 'obsrun';

#No extra stage server sync
#our $stageserver = 'rsync://127.0.0.1/put-repos-main';
#our $stageserver_sync = 'rsync://127.0.0.1/trigger-repos-sync';

#No public download server
#our $repodownload = 'http://software.opensuse.org/download/repositories';

#No package signing server
#our $sign = '/root/bin/sign';

our @reposervers = ('http://localhost:6262');

1

