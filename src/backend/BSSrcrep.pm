#
# Copyright (c) 2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program (see the file COPYING); if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
################################################################
#
# Pgp packet parsing functions
#

package BSSrcrep;

use Digest::MD5 ();
use Digest::SHA ();
use Symbol;
use BSSolv;

use BSConfiguration;
use BSUtil;

use strict;

my $srcrep = "$BSConfig::bsdir/sources";
my $treesdir = $BSConfig::nosharedtrees ? "$BSConfig::bsdir/trees" : $srcrep;
my $eventdir = "$BSConfig::bsdir/events";
my $projectsdir = "$BSConfig::bsdir/projects";		# for upload/pattern meta

my $uploaddir = "$srcrep/:upload";

our $emptysrcmd5 = 'd41d8cd98f00b204e9800998ecf8427e';

if (!defined(&BSSolv::isobscpio)) {
  *BSSolv::isobscpio = sub {die("installed BSSolv does not support obscpio\n") };
  *BSSolv::obscpiostat = sub {die("installed BSSolv does not support obscpio\n") };
  *BSSolv::obscpioopen= sub {die("installed BSSolv does not support obscpio\n") };
  *BSSolv::expandobscpio = sub {die("installed BSSolv does not support obscpio\n") };
}

#
#  Source file handling
#

sub filestat {
  my ($projid, $packid, $filename, $md5) = @_;
  return stat(filepath($projid, $packid, $filename, $md5)) if $filename eq '_serviceerror';
  return BSSolv::obscpiostat("$srcrep/$packid/$md5-$filename") if $filename =~ /\.obscpio$/s;
  return stat("$srcrep/$packid/$md5-$filename");
}

sub fileopen {
  my ($projid, $packid, $filename, $md5, $fd) = @_;
  return open($fd, '<', filepath($projid, $packid, $filename, $md5)) if $filename eq '_serviceerror';
  return BSSolv::obscpioopen("$srcrep/$packid/$md5-$filename", "$srcrep/$packid/deltastore", $fd, $uploaddir) if $filename =~ /\.obscpio$/s;
  return open($fd, '<', "$srcrep/$packid/$md5-$filename");
}

sub filereadstr {
  my ($projid, $packid, $filename, $md5, $nonfatal) = @_;
  die("filereadstr does not work with .obscpio files\n") if $filename =~ /\.obscpio$/s;
  return readstr("$srcrep/$packid/$md5-$filename", $nonfatal);
}

sub filereadxml {
  my ($projid, $packid, $filename, $md5, $dtd, $nonfatal) = @_;
  die("filereadxml does not work with .obscpio files\n") if $filename =~ /\.obscpio$/s;
  return readxml("$srcrep/$packid/$md5-$filename", $dtd, $nonfatal);
}

sub filepath {
  my ($projid, $packid, $filename, $md5) = @_;
  if ($filename eq '_serviceerror') {
    # sigh, _serviceerror files live in the trees...
    my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
    return "$treedir/$md5-_serviceerror" if -e "$treedir/$md5-_serviceerror";
  }
  return "$srcrep/$packid/$md5-$filename";
}

# small helper to build cpio requests
sub cpiofile {
  my ($projid, $packid, $filename, $md5, $forcehandle) = @_;
  if ($forcehandle || $filename =~ /\.obscpio$/s) {
    my $fd = gensym;
    if (!fileopen($projid, $packid, $filename, $md5, $fd)) {
      return {'name' => $filename, 'error' => "fileopen $md5: $!"};
    } else {
      return {'name' => $filename, 'filename' => $fd};
    }
  }
  return {'name' => $filename, 'filename' => filepath($projid, $packid, $filename, $md5)};
}

sub addfile {
  my ($projid, $packid, $tmpfile, $filename, $md5) = @_;

  die("must not upload unexpanded obscpio files\n") if $filename =~ /\.obscpio$/s && BSSolv::isobscpio($tmpfile);
  if (!$md5) {
    open(F, '<', $tmpfile) || die("$tmpfile: $!\n");
    my $ctx = Digest::MD5->new;
    $ctx->addfile(*F);
    close F;
    $md5 = $ctx->hexdigest();
  }
  if (! -e "$srcrep/$packid/$md5-$filename") {
    if (!rename($tmpfile, "$srcrep/$packid/$md5-$filename")) {
      mkdir_p("$srcrep/$packid");
      if (!rename($tmpfile, "$srcrep/$packid/$md5-$filename")) {
        my $err = $!;
        if (! -e "$srcrep/$packid/$md5-$filename") {
          $! = $err;
          die("rename $tmpfile $srcrep/$packid/$md5-$filename: $!\n");
        }
      }
    }
    adddeltastoreevent($projid, $packid, "$md5-$filename") if $filename =~ /\.obscpio$/s;
  } else {
    # get the sha256 sum for the uploaded file
    open(F, '<', $tmpfile) || die("$tmpfile: $!\n");
    my $ctx = Digest::SHA->new(256);
    $ctx->addfile(*F);
    close F;
    my $upload_sha = $ctx->hexdigest();
    # get the sha256 sum for the already existing file
    fileopen($projid, $packid, $filename, $md5, \*F) || die("$srcrep/$packid/$md5-$filename: $!\n");
    $ctx = Digest::SHA->new(256);
    $ctx->addfile(*F);
    close F;
    my $existing_sha = $ctx->hexdigest();
    # if the sha sum is different, but the md5 and filename are the same someone might
    # try to sneak in code.
    unlink($tmpfile);
    if ($upload_sha ne $existing_sha) {
      die("SHA missmatch for same md5sum in $packid for file $filename with sum $md5\n");
    }
  }
  return $md5;
}

#
# make files available in oprojid/opackid available from projid/packid
#
sub copyfiles {
  my ($projid, $packid, $oprojid, $opackid, $files, $except) = @_;

  return if $packid eq $opackid;
  return unless %$files;
  mkdir_p("$srcrep/$packid");
  for my $f (sort keys %$files) {
    next if $except && $except->{$f};
    next if -e "$srcrep/$packid/$files->{$f}-$f";
    if ($f =~ /\.obscpio$/s) {
      copyonefile($projid, $packid, $f, $oprojid, $opackid, $f, $files->{$f});
      next;
    }
    link("$srcrep/$opackid/$files->{$f}-$f", "$srcrep/$packid/$files->{$f}-$f");
    die("link error $srcrep/$opackid/$files->{$f}-$f\n") unless -e "$srcrep/$packid/$files->{$f}-$f";
  }
}

sub copyonefile_tmp {
  my ($projid, $packid, $file, $md5, $tmpname) = @_;
  if ($file =~ /\.obscpio$/s) {
    BSSolv::expandobscpio("$srcrep/$packid/$md5-$file", "$srcrep/$packid/deltastore", $tmpname);
  } else {
    link("$srcrep/$packid/$md5-$file", $tmpname) || die("link $srcrep/$packid/$md5-$file $tmpname: $!\n");
  }
}

sub copyonefile {
  my ($projid, $packid, $file, $oprojid, $opackid, $ofile, $md5) = @_;
  return if -e "$srcrep/$packid/$md5-$file";
  if ($file =~ /\.obscpio$/s) {
    mkdir_p($uploaddir);
    my $tmpname = "$uploaddir/copyonefile.$$";
    copyonefile_tmp($oprojid, $opackid, $ofile, $md5, $tmpname);
    link($tmpname, "$srcrep/$packid/$md5-$file");
    die("link error $tmpname $srcrep/$packid/$md5-$file\n") unless -e "$srcrep/$packid/$md5-$file";
    unlink($tmpname);
    adddeltastoreevent($projid, $packid, "$md5-$file");
    return;
  }
  link("$srcrep/$opackid/$md5-$ofile", "$srcrep/$packid/$md5-$file");
  die("link error $srcrep/$opackid/$md5-$ofile $srcrep/$packid/$md5-$file\n") unless -e "$srcrep/$packid/$md5-$file";
}

# hmm, should this really be here?
sub adddeltastoreevent {
  my ($projid, $packid, $file) = @_;
  mkdir_p("$eventdir/deltastore");
  my $ev = { type => 'deltastore', 'project' => $projid, 'package' => $packid, 'job' => $file };
  my $evname = "deltastore:${projid}::${packid}::${file}";
  $evname = "deltastore:::".Digest::MD5::md5_hex($evname) if length($evname) > 200;
  writexml("$eventdir/deltastore/.$evname.$$", "$eventdir/deltastore/$evname", $ev, $BSXML::event);
  BSUtil::ping("$eventdir/deltastore/.ping");
}


#
#  Tree handling
#

sub lsfiles {
  my ($projid, $packid, $srcmd5, $linkinfo) = @_;
  die("bad packid\n") if $packid =~ /\// || $packid =~ /^\./;	# just in case...
  if ($srcmd5 eq 'empty' || $srcmd5 eq $emptysrcmd5) {
    return {};
  }
  local *F;
  if ($srcmd5 eq 'upload' || $srcmd5 eq 'pattern') {
    my $special_meta = $srcmd5 eq 'upload' ? "$projectsdir/$projid.pkg/$packid.upload-MD5SUMS" : "$projectsdir/$projid.pkg/pattern-MD5SUMS";
    if (!open(F, '<', $special_meta)) {
      return {} if $srcmd5 eq 'pattern';
      die("$projid/$packid has no $srcmd5 revision\n");
    }
  } else {
    die("bad srcmd5 '$srcmd5'\n") if $srcmd5 !~ /^[0-9a-f]{32}$/;
    my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
    if ($BSConfig::nosharedtrees && $BSConfig::nosharedtrees == 2 && ! -e "$treedir/$srcmd5-MD5SUMS" && -e "$srcrep/$packid/$srcmd5-MD5SUMS") {
      $treedir = "$srcrep/$packid";
    }
    if (!open(F, '<', "$treedir/$srcmd5-MD5SUMS")) {
      return {'_linkerror' => $srcmd5} if -e "$srcrep/$packid/$srcmd5-_linkerror";
      return {'_serviceerror' => $srcmd5} if -s "$treedir/$srcmd5-_serviceerror";
      die("$projid/$packid/$srcmd5: not in repository. Either not existing or misconfigured server setting for '\$nosharedtrees' setting in BSConfig.pm\n");
    }
  }
  my @files = <F>;
  close F;
  chomp @files;
  my $files = {map {substr($_, 34) => substr($_, 0, 32)} @files};
  # hack: do not list _signkey in project meta
  if ($linkinfo) {
    $linkinfo->{'lsrcmd5'} = $files->{'/LOCAL'} if $files->{'/LOCAL'};
    $linkinfo->{'srcmd5'} = $files->{'/LINK'} if $files->{'/LINK'};
    $linkinfo->{'xservicemd5'} = $files->{'/SERVICE'} if $files->{'/SERVICE'};
    $linkinfo->{'lservicemd5'} = $files->{'/LSERVICE'} if $files->{'/LSERVICE'};
  }
  delete $files->{'/LINK'};
  delete $files->{'/LOCAL'};
  delete $files->{'/SERVICE'};
  delete $files->{'/LSERVICE'};
  return $files;
}

sub calcsrcmd5 {
  my ($files) = @_;
  my $meta = '';
  $meta .= "$files->{$_}  $_\n" for sort keys %$files;
  return Digest::MD5::md5_hex($meta);
}

sub addmeta {
  my ($projid, $packid, $files) = @_;

  # calculate new meta sum
  my $meta = '';
  $meta .= "$files->{$_}  $_\n" for sort keys %$files;
  my $srcmd5 = Digest::MD5::md5_hex($meta);
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  if (! -e "$treedir/$srcmd5-MD5SUMS") {
    mkdir_p($uploaddir);
    mkdir_p($treedir);
    writestr("$uploaddir/addmeta$$", "$treedir/$srcmd5-MD5SUMS", $meta);
  }
  return $srcmd5;
}

sub existstree {
  my ($projid, $packid, $srcmd5) = @_;
  return 1 if $srcmd5 eq $emptysrcmd5;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  if ($BSConfig::nosharedtrees && $BSConfig::nosharedtrees == 2 && ! -e "$treedir/$srcmd5-MD5SUMS") {
    $treedir = "$srcrep/$packid";
  }
  return -e "$treedir/$srcmd5-MD5SUMS" ? 1 : 0;
}

sub existstree_nocompat {
  my ($projid, $packid, $srcmd5) = @_;
  return 1 if $srcmd5 eq $emptysrcmd5;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  return -e "$treedir/$srcmd5-MD5SUMS" ? 1 : 0;
}

sub knowntrees {
  my ($projid, $packid) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  my @cand = grep {s/-MD5SUMS$//} ls($treedir);
  if ($BSConfig::nosharedtrees && $BSConfig::nosharedtrees == 2) {
    push @cand, grep {s/-MD5SUMS$//} ls("$srcrep/$packid");
    @cand = BSUtil::unify(@cand);
  }
  return @cand;
}

sub copytree {
  my ($projid, $packid, $oprojid, $opackid, $srcmd5) = @_;
  return if $srcmd5 eq $emptysrcmd5;	# nothing to copy
  return if !$BSConfig::nosharedtrees && $packid eq $opackid;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  return if -e "$treedir/$srcmd5-MD5SUMS";	# already known
  my $files = lsfiles($oprojid, $opackid, $srcmd5);
  die("cannot copy service errors\n") if $files->{'_serviceerror'} && keys(%$files) == 1;
  # first copy file content
  copyfiles($projid, $packid, $oprojid, $opackid, $files);
  # then copy the tree data
  my $otreedir = $BSConfig::nosharedtrees ? "$treesdir/$oprojid/$opackid" : "$treesdir/$opackid";
  $otreedir = "$srcrep/$opackid" if $BSConfig::nosharedtrees == 2 && ! -e "$otreedir/$srcmd5-MD5SUMS";
  if (-e "$otreedir/$srcmd5-MD5SUMS") {
    my $meta = readstr("$otreedir/$srcmd5-MD5SUMS");
    mkdir_p($treedir);
    mkdir_p($uploaddir);
    writestr("$uploaddir/$$", "$treedir/$srcmd5-MD5SUMS", $meta);
  } else {
    addmeta($projid, $packid, $files);    # last resort...
  }
}

#
# special link handling
# 

# like addmeta, but adds link information. also stores
# under the "wrong" md5sum.
sub addmeta_link {
  my ($projid, $packid, $files, $srcmd5, $linkinfo) = @_;

  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  if (! -e "$treedir/$srcmd5-MD5SUMS") {
    my $meta = '';
    $meta .= "$files->{$_}  $_\n" for sort keys %$files;
    $meta .= "$linkinfo->{'srcmd5'}  /LINK\n";
    $meta .= "$linkinfo->{'lsrcmd5'}  /LOCAL\n";
    mkdir_p($uploaddir);
    mkdir_p($treedir);
    writestr("$uploaddir/$$", "$treedir/$srcmd5-MD5SUMS", $meta);
  }
}

sub addmeta_linkerror {
  my ($projid, $packid, $srcmd5, $errorfile) = @_;
  if (!link($errorfile, "$srcrep/$packid/$srcmd5-_linkerror")) {
    my $err = "link $errorfile $srcrep/$packid/$srcmd5-_linkerror: $!\n";
    die($err) unless -e "$srcrep/$packid/$srcmd5-_linkerror";
  }
}

sub getlinkerror {
  my ($projid, $packid, $srcmd5) = @_;
  return '' unless -e "$srcrep/$packid/$srcmd5-_linkerror";
  my $log = readstr("$srcrep/$packid/$srcmd5-_linkerror", 1) || 'unknown error';
  chomp $log;
  $log =~ s/.*\n//s;
  return str2utf8xml($log || 'unknown error');
}

sub havelinkerror {
  my ($projid, $packid, $srcmd5) = @_;
  return -e "$srcrep/$packid/$srcmd5-_linkerror";
}

#
# special service handling
# 

# like addmeta, but adds service information after a source
# service finished successfully. stores under the "wrong" md5sum.
sub addmeta_service {
  my ($projid, $packid, $files, $srcmd5, $lservicemd5) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  return if -e "$treedir/$srcmd5-MD5SUMS";      # huh? why did we run twice?
  my $meta = '';
  $meta .= "$files->{$_}  $_\n" for grep {$_ ne '/SERVICE' && $_ ne '/LSERVICE'} sort keys %$files;
  $meta .= "$lservicemd5  /LSERVICE\n";
  mkdir_p($uploaddir);
  mkdir_p($treedir);
  writestr("$uploaddir/$$", "$treedir/$srcmd5-MD5SUMS", $meta);
  unlink("$treedir/$srcmd5-_serviceerror");
}

# check if we can reuse an already existing servicemark
# used in servicemark_noservice
sub can_reuse_oldservicemark {
  my ($projid, $packid, $files, $servicemark) = @_;

  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  return 0 if -e "$treedir/$servicemark-_serviceerror";
  my $oldmeta = readstr("$treedir/$servicemark-MD5SUMS", 1);
  # does not exist -> reuse it and hope for the best
  return 1 if !$oldmeta;
  # be extra carful here and make sure our data matches
  # calculate LSRCMD5 from file list
  my $nfiles = { %$files };
  delete $nfiles->{$_} for grep {/^_service[:_]/} keys %$nfiles;
  $nfiles->{'/SERVICE'} = $servicemark;
  my $meta = '';
  $meta .= "$nfiles->{$_}  $_\n" for sort keys %$nfiles;
  my $nsrcmd5 = Digest::MD5::md5_hex($meta);
  # calculate new meta
  $meta = '';
  $meta .= "$files->{$_}  $_\n" for grep {$_ ne '/SERVICE' && $_ ne '/LSERVICE'} sort keys %$files;
  $meta .= "$nsrcmd5  /LSERVICE\n";
  return 1 if $oldmeta eq $meta;
  return 0;
}

sub addmeta_serialize_servicerun {
  my ($projid, $packid, $srcmd5) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  mkdir_p($treedir);
  local *FF;
  BSUtil::lockopen(\*FF, '+>>', "$treedir/$srcmd5-_serviceerror");
  if (-s FF) {
    # already running or failed!
    close FF;   # free lock
    return undef;
  }
  writestr("$treedir/.$srcmd5-_serviceerror", "$treedir/$srcmd5-_serviceerror", "service in progress\n");
  close FF;     # free lock
  return 1;
}

sub addmeta_serviceerror {
  my ($projid, $packid, $srcmd5, $error) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  if (!defined($error)) {
    unlink("$treedir/$srcmd5-_serviceerror");
  } else {
    # normalize the error
    $error =~ s/[\r\n]+$//s;
    $error ||= 'unknown service error';
    mkdir_p($treedir);
    writestr("$treedir/.$srcmd5-_serviceerror", "$treedir/$srcmd5-_serviceerror", "$error\n");
  }
}

sub getserviceerror {
  my ($projid, $packid, $srcmd5) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  my $errorfile = "$treedir/$srcmd5-_serviceerror";
  return '' unless -e $errorfile;
  local *SERROR;
  return '' unless open(SERROR, '<', $errorfile);
  my $size = -s SERROR;
  sysseek(SERROR, $size - 1024, 0) if $size > 1024;
  my $error = '';
  1 while sysread(SERROR, $error, 1024, length($error));
  close SERROR;
  $error =~ s/[\r\n]+$//s;
  $error =~ s/.*[\r\n]//s;
  return str2utf8xml($error || 'unknown service error');
}

sub serviceerrorfile {
  my ($projid, $packid, $srcmd5) = @_;
  my $treedir = $BSConfig::nosharedtrees ? "$treesdir/$projid/$packid" : "$treesdir/$packid";
  return "$treedir/$srcmd5-_serviceerror";
}

1;
