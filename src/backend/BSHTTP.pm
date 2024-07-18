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

use BSCpio;

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

sub urlencode {
  my ($str, $iscgi) = @_;
  if ($iscgi) {
    $str =~ s/([\000-\037<>;\"#\?&\+=%[\177-\377])/sprintf("%%%02X",ord($1))/sge;
    $str =~ tr/ /+/;
  } else {
    $str =~ s/([\000-\040<>;\"#\?&\+=%[\177-\377])/sprintf("%%%02X",ord($1))/sge;
  }
  return $str;
}

sub urldecode {
  my ($str, $iscgi) = @_;
  $str =~ tr/+/ / if $iscgi;
  $str =~ s/%([a-fA-F0-9]{2})/chr(hex($1))/sge;
  return $str;
}

sub queryencode {
  my (@args, $iscgi) = @_;
  for (@args) {
    $_ = urlencode($_, $iscgi);
    s/%3D/=/;	# convert now escaped = back
  }
  return join('&', @args);
}

sub querydecodekv {
  my ($query) = @_;
  my @res;
  for my $querypart (split('&', $query)) {
    my ($name, $value) = split('=', $querypart, 2);
    push @res, $name, $value;
  }
  for (@res) {
    $_ = urldecode($_, 1) if defined($_) && /[\+%]/s;
  }
  return @res;
}

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
  my $sock = $req->{'__socket'};
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
	  my $r = sysread($sock, $qu, 8192, length($qu));
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
	  my $r = sysread($sock, $qu, 8192, length($qu));
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
	my $r = sysread($sock, $qu, 8192, length($qu));
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
	  my $r = sysread($sock, $qu, 8192, length($qu));
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
      my $r = sysread($sock, $qu, $m, length($qu));
      if (!$r &&  (defined($r) || ($! != POSIX::EINTR && $! != POSIX::EWOULDBLOCK))) {
	$req->{'__eof'} = 1;
	die("unexpected EOF\n") if defined($cl) || ($exact && defined($maxl));
	$cl = $maxl = length($qu);
      }
    }
    $cl -= $maxl if defined $cl;
    $req->{'__cl'} = $cl;
    $req->{'__data'} = substr($qu, $maxl, length($qu) - $maxl, '');
    $req->{'__eof'} = 1 if defined($cl) && $cl == 0;
    return $qu;
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
    '__cl' => -s *{$fd},
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
  my $ctx;
  $ctx = Digest::MD5->new if $param->{'withmd5'};
  my $fd;
  open($fd, '>', $fn) || die("$fn: $!\n");
  my $size = 0;
  while(1) {
    my $s = read_data($req, 8192);
    last if $s eq '';
    (syswrite($fd, $s) || 0) == length($s) || die("syswrite: $!\n");
    $size += length($s);
    $ctx->add($s) if $ctx;
  }
  close($fd) || die("close: $!\n");
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
  while(1) {
    my $cpiohead = read_data($req, 110, 1);
    die("cpio: not a 'SVR4 no CRC ascii' cpio\n") unless substr($cpiohead, 0, 6) eq '070701';
    my ($ent, $namesize, $namepad, $size, $pad) = BSCpio::parsecpiohead($cpiohead);
    die("cannot parse cpio header\n") unless $ent;
    die("ridiculous long filename\n") if $namesize > 8192;
    my $name = read_data($req, $namesize + $namepad, 1);
    $name = substr($name, 0, $namesize);
    $name =~ s/\0.*//s;
    last if !$size && $name eq 'TRAILER!!!';
    $name =~ s/^\.\///s;
    $ent->{'name'} = $name;

    die("cpio filename is '.' or '..'\n") if $name eq '.' || $name eq '..';
    if ($param->{'acceptsubdirs'} || $param->{'createsubdirs'}) {
      die("cpio filename is illegal: $name\n") if "/$name/" =~ /\/\.{0,2}\//s;
    } else {
      die("cpio filename contains a '/': $name\n") if $name =~ /\//s;
    }

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
	$ent->{'name'} = $name = $param->{'map'}->($param, $name, $ent);
      } else {
	$ent->{'name'} = $name = "$param->{'map'}$name";
      }
    }

    if (!defined($name)) {
      # skip entry
      $size += $pad;
      while ($size) {
        my $m = $size > 8192 ? 8192 : $size;
        read_data($req, $m, 1);
        $size -= $m;
      }
      next;
    }
    push @res, $ent;
    my $mode = $ent->{'mode'};
    my $cpiotype = $ent->{'cpiotype'};
    my $ctx;
    $ctx = Digest::MD5->new if $withmd5 && $cpiotype != 4;
    my $fd;
    if (defined($dn)) {
      my $filename = "$dn/$name";
      if ($cpiotype == 4 && $param->{'createsubdirs'}) {
	die("directory has non-zero size\n") if $size;
	if (! -d $filename) {
	  unlink($filename) unless $param->{'no_unlink'};
	  mkdir($filename) || die("mkdir $filename: $!\n");
	}
      } else {
	die("can only unpack plain files from cpio archive, file $name, cpiotype was $cpiotype\n") unless $cpiotype == 8;
	unlink($filename) unless $param->{'no_unlink'};
	open($fd, '>', $filename) || die("$filename: $!\n");
      }
    } else {
      $ent->{'data'} = '';
    }
    while ($size) {
      my $m = $size > 8192 ? 8192 : $size + $pad;
      my $data = read_data($req, $m, 1);
      if ($m > $size) {
	substr($data, -$pad, $pad, '');
	$m = $size;
      }
      $size -= $m;
      if (defined($dn)) {
        (syswrite($fd, $data, $m) || 0) == $m || die("syswrite: $!\n");
      } else {
        $ent->{'data'} .= $data;
      }
      $ctx->add($data) if $ctx;
    }
    if ($fd) {
      close($fd) || die("close: $!\n");
      my $mtime = $ent->{'mtime'};
      utime($mtime, $mtime, "$dn/$name") if $mtime;
    }
    $ent->{'md5'} = $ctx->hexdigest if $ctx;
    $param->{'cpiopostfile'}->($param, $ent) if $param->{'cpiopostfile'};
  }
  return \@res;
}

sub swrite {
  my ($sock, $data, $chunked) = @_;
  return if $chunked && $data eq '';	# can't write that
  $data = sprintf("%X\r\n", length($data)).$data."\r\n" if $chunked;
  while (length($data)) {
    my $l = syswrite($sock, $data, length($data));
    if (!$l) {
      next if !defined($l) && ($! == POSIX::EINTR || $! == POSIX::EWOULDBLOCK);
      die("socket write: $!\n");
    }
    $data = substr($data, $l);
  }
}

sub create_writer {
  my ($sock, $chunked) = @_;
  return sub { swrite($sock, $_[0], $chunked) };
}

sub cpio_sender {
  my ($param, $sock) = @_;
  my $writer = create_writer($sock, $param->{'chunked'});
  BSCpio::writecpio($writer, $param->{'cpiofiles'}, 'collecterrors' => $param->{'collecterrors'}, 'follow' => $param->{'follow'});
  return '';
}

sub file_sender {
  my ($param, $sock) = @_;

  my $bytes = $param->{'bytes'};
  my $data;
  my $fd;
  if (ref($param->{'filename'})) {
    $fd = $param->{'filename'};
  } else {
    open($fd, '<', $param->{'filename'}) || die("$param->{'filename'}: $!\n")
  }
  while(1) {
    last if defined($bytes) && !$bytes;
    my $r = sysread($fd, $data, 8192);
    last unless $r;
    if ($bytes) {
      $data = substr($data, 0, $bytes) if length($data) > $bytes;
      $bytes -= length($data);
    }
    swrite($sock, $data, $param->{'chunked'});
  }
  close $fd unless ref $param->{'filename'};
  return '';
}

sub reply_sender {
  my ($param, $sock) = @_;
  my $data;
  my $req = $param->{'reply_req'};
  my $chunked = $param->{'chunked'};
  while (($data = read_data($req, 8192)) ne '') {
    swrite($sock, $data, $chunked);
  }
  return '';
}

1;
