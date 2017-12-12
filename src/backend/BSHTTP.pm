#
# Copyright (c) 2006, 2007 Michael Schroeder, Novell Inc.
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
# HTTP protocol functions. Also contains file/cpio sender/receiver.
#

package BSHTTP;

use POSIX;
use Digest::MD5 ();
use Fcntl qw(:DEFAULT);
BEGIN { Fcntl->import(':seek') unless defined &SEEK_SET; }

use strict;

=head1 NAME

BSHTTP

=cut

=head1 SYNOPSIS

 TODO

=cut

=head1 DESCRIPTION

This library contains functions to handle http requests in obs

=cut

=head1 FUNCTIONS / METHODS

=cut


sub gethead {
  my ($h, $t) = @_;

  my ($field, $data);
  for (split(/[\r\n]+/, $t)) {
    next if $_ eq '';
    if (/^[ \t]/s) {
      s/^\s*/ /s;
      $h->{$field} .= $_ if defined $field;
    } else {
      ($field, $data) = split(/\s*:\s*/, $_, 2);
      $field =~ tr/A-Z/a-z/;
      $h->{$field} = $h->{$field} && $h->{$field} ne '' ? "$h->{$field},$data" : $data;
    }
  }
}

=head2 BSHTTP::forwardheaders

Return selected headers from the request to be forwarded

=cut

sub forwardheaders {
  my ($req, @except) = @_;

  return () unless defined $req->{'rawheaders'};
  my @h;
  my $exceptre;
  if (@except) {
    $exceptre = join('|', @except);
    $exceptre = qr/^(?:$exceptre)\s*:/i;
  }
  for (split(/[\r\n]+/, $req->{'rawheaders'})) {
    push @h, $_ unless $exceptre && /$exceptre/; 
  }
  return @h;
}

sub makemultipart {
  my ($boundary, @parts) = @_;
  my $data = '';
  for my $part (@parts) {
    $data .= "\r\n--$boundary\r\n";
    $data .= "$_\r\n" for @{$part->{'headers'} || []};
    $data .= "\r\n";
    $data .= $part->{'data'} if defined $part->{'data'};
  }
  $data .= "\r\n--$boundary--\r\n";
  $data =~ s/^\r\n//s;
  return $data;
}

sub authquote {
  my ($q) = @_;
  $q =~ s/(.)/sprintf("%%%02X", ord($1))/ge;
  return $q;
}

sub parseauthenticate {
  my ($auth) = @_;
  $auth =~ s/%/%25/g;
  $auth =~ s/\\(.)/$1 eq '%' ? '%' : sprintf("%%%02X", ord($1))/ge;
  $auth =~ s/\"(.*?)\"/authquote($1)/ge;
  $auth =~ s/\s*=\s*/=/g;	# get rid of bad space
  my @auth = split(/\s*,\s*/, $auth);
  for (splice @auth) {
    s/%([a-fA-F0-9]{2})/chr(hex($1))/ge;
    if (/^([^=\s]+)(?:\s+(.*?))?$/s) {
      push @auth, lc($1), {};
      $_ = $2;
    }
    next unless @auth && defined($_);
    if (/^(.*?)=(.*)/) {
      push @{$auth[-1]->{lc($1)}}, $2;
    } else {
      push @{$auth[-1]->{'token'}}, $_;
    }
  }
  return @auth;
}

sub unexpected_eof {
  my ($req) = @_;
  $req->{'__eof'} = 1 if $req;
  die("unexpected EOF\n");
}


=head2 BSHTTP::read_data

read data from socket, do chunk decoding if needed

  my $ret = BSHTTP::read_data(
    # request data
    {
      headers	  => {
			transfer-encoding => 'chunked'
			content-length	  => ...
		     }, #
      __socket	  => <FILEHANDLE> , # filehandle to socket or opened file
      __cl	  => ...	  , #
      __data
    },
    $maxl,	  # if undef read as much as you can
    $exact,	  # Boolean
		  # if 1 read maxl data
		  # if maxl == undef -> read to eof
  );

=cut

sub read_data {
  my ($req, $maxl, $exact) = @_;

  my $ret = '';
  my $hdr = $req->{'headers'} || {};
  local *S = $req->{'__socket'};
  if ($hdr->{'transfer-encoding'} && lc($hdr->{'transfer-encoding'}) eq 'chunked') {
    my $cl = $req->{'__cl'} || 0;
    if ($cl < 0) {
      die("unexpected EOF\n") if $exact && defined($maxl) && length($ret) < $maxl;
      return $ret;
    }
    my $qu = $req->{'__data'};
    while (1) {
      if (defined($maxl) && $maxl <= $cl) {
	while(length($qu) < $maxl) {
	  my $r = sysread(S, $qu, 8192, length($qu));
	  unexpected_eof($req) if !$r && (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK));
	}
	$ret .= substr($qu, 0, $maxl);
	$req->{'__cl'} = $cl - $maxl;
	$req->{'__data'} = substr($qu, $maxl);
	return $ret;
      }
      if ($cl) {
	# no maxl or maxl > cl, read full cl
	while(length($qu) < $cl) {
	  my $r = sysread(S, $qu, 8192, length($qu));
	  unexpected_eof($req) if !$r && (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK));
	}
	$ret .= substr($qu, 0, $cl);
	$qu = substr($qu, $cl);
	$maxl -= $cl if defined $maxl;
	$cl = 0;
	if (!defined($maxl) && !$exact) { # no maxl, return every chunk
	  $req->{'__cl'} = $cl;
	  $req->{'__data'} = $qu;
	  return $ret;
	}
      }
      # reached end of chunk, prepare for next one
      while ($qu !~ /\r?\n/s) {
	my $r = sysread(S, $qu, 8192, length($qu));
        unexpected_eof($req) if !$r && (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK));
      }
      if (substr($qu, 0, 1) eq "\n") {
	$qu = substr($qu, 1);
	next;
      }
      if (substr($qu, 0, 2) eq "\r\n") {
	$qu = substr($qu, 2);
	next;
      }
      die("bad CHUNK data: $qu\n") unless $qu =~ /^([0-9a-fA-F]+)/;
      $cl = hex($1);
      die if $cl < 0;
      $qu =~ s/^.*?\r?\n//s;
      if ($cl == 0) {
	$req->{'__cl'} = -1;	# mark EOF
	$req->{'__eof'} = 1;
	die("unexpected EOF\n") if $exact && defined($maxl) && length($ret) < $maxl;
	# read trailer
	$qu = "\r\n$qu";
	while ($qu !~ /\n\r?\n/s) {
	  my $r = sysread(S, $qu, 8192, length($qu));
	  unexpected_eof($req) if !$r && (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK));
	}
	$qu =~ /^(.*?)\n\r?\n/;
	# get trailing header
	gethead($hdr, length($1) >= 2 ? substr($1, 2) : '');
	return $ret;
      }
    }
  } else {
    my $qu = $req->{'__data'};
    my $cl = $req->{'__cl'};
    $cl = $hdr->{'content-length'} unless defined $cl;
    if (defined($cl) && (!defined($maxl) || $maxl > $cl)) {
      die("unexpected EOF\n") if $exact && defined($maxl);
      $maxl = $cl >= 0 ? $cl : 0;
    }
    while (!defined($maxl) || length($qu) < $maxl) {
      my $m = ($maxl || 0) - length($qu);
      $m = 8192 if $m < 8192;
      my $r = sysread(S, $qu, $m, length($qu));
      if (!$r &&  (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK))) {
	$req->{'__eof'} = 1;
	die("unexpected EOF\n") if defined($cl) || ($exact && defined($maxl));
	$cl = $maxl = length($qu);
      }
    }
    $cl -= $maxl if defined($cl);
    $ret = substr($qu, 0, $maxl);
    $req->{'__cl'} = $cl;
    $req->{'__data'} = substr($qu, $maxl);
    $req->{'__eof'} = 1 if defined($cl) && $cl == 0;
    return $ret;
  }
}

sub str2req {
  my ($str) = @_;
  my $req = {
    '__data' => $str,
    '__cl' => length($str),
  };
  return $req;
}

sub fd2req {
  my ($fd) = @_;
  my $req = {
    '__data' => '',
    '__socket' => $fd,
    '__cl' => -s *$fd,
  };
  return $req;
}

sub null_receiver {
  my ($req, $param) = @_;
  1 while(read_data($req, 8192) ne '');
  return '';
}

sub file_receiver {
  my ($req, $param) = @_;

  die("file_receiver: no filename\n") unless defined $param->{'filename'};
  my $fn = $param->{'filename'};
  my $withmd5 = $param->{'withmd5'};
  local *F;
  my $ctx;
  $ctx = Digest::MD5->new if $withmd5;
  open(F, '>', $fn) || die("$fn: $!\n");
  my $size = 0;
  while(1) {
    my $s = read_data($req, 8192);
    last if $s eq '';
    (syswrite(F, $s) || 0) == length($s) || die("syswrite: $!\n");
    $size += length($s);
    $ctx->add($s) if $ctx;
  }
  close(F) || die("close: $!\n");
  my $res = {size => $size};
  $res->{'md5'} = $ctx->hexdigest if $ctx;
  return $res;
}


=head2 BSHTTP::cpio_receiver

TODO: add meaningful explanation

  my $result = BSHTTP::cpio_receiver(
    # options given to read_data
    {
      ... # SEE BSHTTP::read_data
    },
    # all parameters are optional
    {
      directory	    => <STRING>        , # store files in given directory
					 # (Otherwise data is stored in $result->[]
      withmd5	    => <BOOLEAN>       , #
      acceptsubdirs => <BOOLEAN>       , #
      createsubdirs => <BOOLEAN>       , #
      accept	    => <REGEX|CODEREF> , # Check included files
					 # by regex or function
      map	    => <REGEX|CODEREF> , # Rename files
					 # by regex or function
      no_unlink	    => <BOOLEAN>       , # Do not remove already existent
					 # (sub)directories. Only relevant
					 # if directory is given
					 #
      cpiopostfile  => ... , #
    }
  );

  # returns an ArrayRef of HashRefs
  # $result = [
  #   {
  #	name	  => <STRING>	  , # filename
  #	size	  => ...
  #	mtime	  => ...	  ,
  #	mode	  => ...	  ,
  #	md5	  => <STRING>	  , # md5 as hexdigest
  #				    # only if withmd5 was true
  #	data	  => <BINARYDATA> , # binary data from file
  #				    # only if no directory was given
  #   },
  #   {
  #	....
  #   },
  #   ....
  # ];

=cut

sub cpio_receiver {
  my ($req, $param) = @_;
  my @res;
  my $dn = $param->{'directory'};
  my $withmd5 = $param->{'withmd5'};
  local *F;
  while(1) {
    my $cpiohead = read_data($req, 110, 1);
    die("cpio: not a 'SVR4 no CRC ascii' cpio\n") unless substr($cpiohead, 0, 6) eq '070701';
    my $mode = hex(substr($cpiohead, 14, 8));
    my $mtime = hex(substr($cpiohead, 46, 8));
    my $size  = hex(substr($cpiohead, 54, 8));
    if ($size == 0xffffffff) {
      # build service length extension
      $cpiohead .= read_data($req, 16, 1);
      $size = hex(substr($cpiohead, 62, 8)) * 4294967296. + hex(substr($cpiohead, 70, 8));
      substr($cpiohead, 62, 16) = '';
    }
    my $nsize = hex(substr($cpiohead, 94, 8));
    die("ridiculous long filename\n") if $nsize > 8192;
    my $nsizepad = $nsize;
    $nsizepad += 4 - ($nsize + 2 & 3) if $nsize + 2 & 3;
    my $name = read_data($req, $nsizepad, 1);
    $name =~ s/\0.*//s;
    $name =~ s/^\.\///s;
    my $sizepad = $size;
    $sizepad += 4 - ($size % 4) if $size % 4;
    last if !$size && $name eq 'TRAILER!!!';
    if ($param->{'acceptsubdirs'} || $param->{'createsubdirs'}) {
      die("cpio filename is illegal: $name\n") if "/$name/" =~ /\/\.{0,2}\//s;
    } else {
      die("cpio filename contains a '/': $name\n") if $name =~ /\//s;
    }
    die("cpio filename is '.' or '..'\n") if $name eq '.' || $name eq '..';
    my $ent = {'name' => $name, 'size' => $size, 'mtime' => $mtime, 'mode' => $mode};
    if ($param->{'accept'}) {
      if (ref($param->{'accept'})) {
	die("illegal file in cpio archive: $name\n") unless $param->{'accept'}->($param, $name, $ent);
      } else {
	die("illegal file in cpio archive: $name\n") unless $name =~ /$param->{'accept'}/;
      }
    }
    if ($param->{'map'}) {
      $ent->{'unmappedname'} = $name;
      if (ref($param->{'map'})) {
	$ent->{'name'} = $name = $param->{'map'}->($param, $name);
      } else {
	$ent->{'name'} = $name = "$param->{'map'}$name";
      }
    }
    if (!defined($name)) {
      # skip entry
      while ($sizepad) {
        my $m = $sizepad > 8192 ? 8192 : $sizepad;
        read_data($req, $m, 1);
        $sizepad -= $m;
      }
      next;
    }
    push @res, $ent;
    my $ctx;
    $ctx = Digest::MD5->new if $withmd5;
    if (defined($dn)) {
      my $filename = "$dn/$name";
      if (($mode & 0xf000) == 0x4000 && $param->{'createsubdirs'}) {
	die("directory has non-zero size\n") if $sizepad;
	if (! -d $filename) {
	  unlink($filename) unless $param->{'no_unlink'};
	  mkdir($filename) || die("mkdir $filename: $!\n");
	}
      } else {
	die("can only unpack plain files from cpio archive, file $name, mode was $mode\n") unless ($mode & 0xf000) == 0x8000;
	unlink($filename) unless $param->{'no_unlink'};
	open(F, '>', $filename) || die("$filename: $!\n");
      }
    } else {
      $ent->{'data'} = '';
    }
    while ($sizepad) {
      my $m = $sizepad > 8192 ? 8192 : $sizepad;
      my $data = read_data($req, $m, 1);
      $sizepad -= $m;
      $size -= $m;
      $m += $size if $size < 0;
      if (defined($dn)) {
        (syswrite(F, $data, $m) || 0) == $m || die("syswrite: $!\n");
      } else {
        $ent->{'data'} .= substr($data, 0, $m);
      }
      $ctx->add($size >= 0 ? $data : substr($data, 0, $m)) if $ctx;
    }
    if (defined($dn) && ($mode & 0xf000) != 0x4000) {
      close(F) || die("close: $!\n");
      utime($mtime, $mtime, "$dn/$name") if $mtime;
    }
    $ent->{'md5'} = $ctx->hexdigest if $ctx && ($mode & 0xf000) != 0x4000;
    $param->{'cpiopostfile'}->($param, $ent) if $param->{'cpiopostfile'};
  }
  return \@res;
}

sub swrite {
  my ($sock, $data, $chunked) = @_;
  local *S = $sock;
  return if $chunked && $data eq '';	# can't write that
  $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $chunked;
  while (length($data)) {
    my $l = syswrite(S, $data, length($data));
    die("socket write: $!\n") unless $l;
    $data = substr($data, $l);
  }
}

sub makecpiohead {
  my ($file, $s) = @_; 
  return "07070100000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000b00000000TRAILER!!!\0\0\0\0" if !$file;
  my $name = $file->{'name'};
  my $mode = $file->{'mode'} || 0x81a4;
  my $mtime = $file->{'mtime'} || $s->[9];
  my $h = sprintf("07070100000000%08x000000000000000000000001", $mode);
  if ($s->[7] > 0xffffffff) {
    # build service length extension
    my $top = int($s->[7] / 4294967296.);
    $h .= sprintf("%08xffffffff%08x%08x", $mtime, $top, $s->[7] - $top * 4294967296.);
  } else {
    $h .= sprintf("%08x%08x", $mtime, $s->[7]);
  }
  $h .= "00000000000000000000000000000000";
  $h .= sprintf("%08x", length($name) + 1); 
  $h .= "00000000$name\0";
  $h .= substr("\0\0\0\0", (length($h) & 3)) if length($h) & 3;
  my $pad = $s->[7] % 4 ? substr("\0\0\0\0", $s->[7] % 4) : ''; 
  return ($h, $pad);
}

sub cpio_sender {
  my ($param, $sock) = @_;

  local *F;
  my ($data, $pad);
  my $errors = {'__errors' => 1, 'name' => '.errors', 'data' => ''};
  for my $file (@{$param->{'cpiofiles'} || []}, $errors) {
    my @s;
    if ($file->{'error'}) {
	$errors->{'data'} .= "$file->{'name'}: $file->{'error'}\n";
	next;
    }
    if (exists $file->{'filename'}) {
      my $filename = $file->{'filename'};
      if (ref($filename)) {
	*F = $filename;
      } else {
	@s = lstat($filename);
	if (!@s) {
	  $errors->{'data'} .= "$file->{'name'}: $filename: $!\n";
	  next;
	}
	if (-l _) {
	  if (!$file->{'follow'} && !$param->{'follow'}) {
	    $errors->{'data'} .= "$file->{'name'}: $filename: is a symlink\n";
	    next;
	  }
	} elsif (! -f _) {
	  $errors->{'data'} .= "$file->{'name'}: $filename: not a plain file\n";
	  next;
	}
	if (!open(F, '<', $filename)) {
	  $errors->{'data'} .= "$file->{'name'}: $filename: $!\n";
	  next;
	}
      }
      @s = stat(F);
      if (!@s) {
	$errors->{'data'} .= "$file->{'name'}: fstat: $!\n";
	close F unless ref $filename;
	next;
      }
      if (ref($filename)) {
	my $off = sysseek(F, 0, Fcntl::SEEK_CUR) || 0;
	$s[7] -= $off if $off > 0;
      }
      ($data, $pad) = makecpiohead($file, \@s);
      my $l = $s[7];
      my $r = 0;
      while(1) {
	$r = sysread(F, $data, $l > 8192 ? 8192 : $l, length($data)) if $l;
	die("error while reading '$filename': $!\n") unless defined $r;
	$data .= $pad if $r == $l;
	swrite($sock, $data, $param->{'chunked'});
	$data = '';
	$l -= $r;
	last unless $l;
      }
      die("internal error\n") if $l;
      close F unless ref $filename;
    } else {
      next if $file->{'__errors'} && $file->{'data'} eq '';
      $s[7] = length($file->{'data'});
      $s[9] = time;
      ($data, $pad) = makecpiohead($file, \@s);
      $data .= "$file->{'data'}$pad";
      while ($param->{'chunked'} && length($data) > 8192) {
	# keep chunks small
	swrite($sock, substr($data, 0, 4096), $param->{'chunked'});
	$data = substr($data, 4096);
      }
      swrite($sock, $data, $param->{'chunked'});
    }
  }
  $data = makecpiohead();
  swrite($sock, $data, $param->{'chunked'});
  return '';
}

sub file_sender {
  my ($param, $sock) = @_;
  local *F;

  my $bytes = $param->{'bytes'};
  my $data;
  if (ref($param->{'filename'})) {
    *F = $param->{'filename'};
  } else {
    open(F, '<', $param->{'filename'}) || die("$param->{'filename'}: $!\n")
  }
  while(1) {
    last if defined($bytes) && !$bytes;
    my $r = sysread(F, $data, 8192);
    last unless $r;
    if ($bytes) {
      $data = substr($data, 0, $bytes) if length($data) > $bytes;
      $bytes -= length($data);
    }
    swrite($sock, $data, $param->{'chunked'});
  }
  close F unless ref $param->{'filename'};
  return '';
}

1;
