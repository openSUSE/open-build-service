#!/usr/bin/env python

import atexit
import os
import pwd
import shutil
import sys
import tempfile
import urllib2

from osc import conf, core

if sys.hexversion >= 0x2050000:
    from xml.etree.cElementTree import ElementTree
else:
    from cElementTree import ElementTree

apiserver = 'https://api.opensuse.org'
downloadmirror = 'http://download.opensuse.org/repositories'

# If a download fails, try up to this many times before giving up
retries = 2

# If this is True, remove older files after updating
cleanup = True

rootdir = "/srv/obs" # package default
ownername = "obsrun"
owneruid = pwd.getpwnam(ownername)[2]

projectdir = rootdir + "/projects/"

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print "Call this script with <project> <repository> <architecture> arguments.\n"
        print "To mirror openSUSE 10.2 as base distro, please call:\n\n"
        print "  obs_mirror_project.py openSUSE:10.2 standard i586 \n"
        sys.exit(1)

    project = sys.argv[1]
    repository = sys.argv[2]
    architecture = sys.argv[3]

    destinationdir = "%s/build/%s/%s/%s/:full/" % (rootdir, project, repository, architecture)
    downloadurl = "%s/%s/%s" % (downloadmirror, project, repository)
    
    # Initialise osc lib
    conf.get_config()
    conf.config['apiurl'] = conf.config['scheme'] + '://' + conf.config['apisrv']
    conf.config['user'] = conf.config['auth_dict'][conf.config['apisrv']]['user']
    conf.init_basicauth(conf.config)

    # Create target directories
    for d in (destinationdir, projectdir):
        if not os.path.isdir(d):
            print "Creating %s" % d
            os.makedirs(d, 0755)
            os.chown(d, owneruid, -1)

#    # Copy project metadata from upstream server
#    print "Updating project metadata"

#    f = open("%s/%s.xml" % (projectdir, project), 'w')
#    f.write(''.join(core.show_project_meta(apiserver, project)))
#    os.chown(f.name, owneruid, -1)
#    f.close()

#    f = open("%s/%s.conf" % (projectdir, project), 'w')
#    f.write(''.join(core.show_project_conf(apiserver, project)))
#    os.chown(f.name, owneruid, -1)
#    f.close()

    # Download packages
    tmpdir = tempfile.mkdtemp()
    atexit.register(shutil.rmtree, tmpdir)

    # Get package list
    filenames = core.get_binarylist(conf.config['apiurl'], project, repository, architecture)

    for filename in filenames:
	if filename.contains("debuginfo") or filename.contains("debugsource"):
		print "Skipping debug package: %s" % filename
		continue

        if not os.path.exists('%s/%s' % (destinationdir, filename)):
            attempt = 0
            done = False
            while not done:
                try:
                    sys.stdout.write("Downloading %s [  0%%]" % filename)
                    sys.stdout.flush()
                    tmpfilename = '%s/%s' % (tmpdir, filename)
                    targetfilename = '%s/%s' % (destinationdir, filename)
                    tmpfd = open(tmpfilename, 'w')
                    binstream = core.http_GET('%s/build/%s/%s/%s/_repository/%s' % (apiserver, project, repository, architecture, filename))

                    binsize = int(binstream.headers['content-length'])
                    downloaded = 0

                    downloading = True
                    while downloading:
                        buf = binstream.read(16384)
                        if buf:
                            tmpfd.write(buf)
                            downloaded += len(buf)
                        else:
                            downloading = False
                        completion = str(int((float(downloaded)/binsize)*100))
                        sys.stdout.write('%s%*s%%]' % ('\b'*5, 3, completion))
                        sys.stdout.flush()
                    tmpfd.close()
                    sys.stdout.write('\n')
                    shutil.move(tmpfilename, targetfilename)
                    os.chown(targetfilename, owneruid, -1)
                    done = True
                except urllib2.URLError, e:
                    print e
                    attempt += 1
                    if attempt >= retries:
                        print "Tried %s times. Giving up" % attempt
                        done = True


    if cleanup:
        for localfilename in ['%s/%s' % (destinationdir, f) for f in os.listdir(destinationdir) if f.endswith('.rpm') and f not in filenames]:
            print "Removing %s" % localfilename
            os.unlink(localfilename)

    print "Mirroring succeeded :)"
    print "Please restart the scheduler to rescan your projects !"

