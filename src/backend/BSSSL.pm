#
# Copyright (c) 2007 Michael Schroeder, Novell Inc.
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
# SSL Socket wrapper. Like Net::SSLeay::Handle, but can tie
# inplace and also supports servers. Plus, it uses the more useful
# Net::SSLeay::read instead of Net::SSLeay::ssl_read_all.
#

package BSSSL;

use POSIX;
use Socket;
use Net::SSLeay;

use strict;

my $sslctx;
my $ssleay_inited;

sub initssleay {
  Net::SSLeay::load_error_strings();
  Net::SSLeay::SSLeay_add_ssl_algorithms();
  Net::SSLeay::randomize();
  $ssleay_inited = 1;
}

sub die_with_error_stack {
  my ($msg) = @_;
  my @errs;
  my $err;
  while ($err = Net::SSLeay::ERR_get_error()) {
    push @errs, Net::SSLeay::ERR_error_string($err);
  }
  die("$msg: ".join(', ', @errs)."\n");
}

sub newctx {
  my (%opts) = @_;
  initssleay() unless $ssleay_inited;
  my $ctx = Net::SSLeay::CTX_new() or die("CTX_new failed!\n");
  Net::SSLeay::CTX_set_options($ctx, &Net::SSLeay::OP_ALL);
  if ($opts{'keyfile'}) {
    Net::SSLeay::CTX_use_PrivateKey_file($ctx, $opts{'keyfile'}, &Net::SSLeay::FILETYPE_PEM) || die("PrivateKey $opts{'keyfile'} failed to load\n");
  }
  if ($opts{'certfile'}) {
    # CTX_use_certificate_chain_file expects PEM format anyway, client cert first, chain certs after that
    Net::SSLeay::CTX_use_certificate_chain_file($ctx, $opts{'certfile'}) || die("certificate $opts{'certfile'} failed to load\n");
  }
  if (defined(&Net::SSLeay::CTX_set_tmp_ecdh) && Net::SSLeay::SSLeay() < 0x10100000) {
    my $curve = Net::SSLeay::OBJ_txt2nid('prime256v1');
    my $ecdh  = Net::SSLeay::EC_KEY_new_by_curve_name($curve);
    Net::SSLeay::CTX_set_tmp_ecdh($ctx, $ecdh);
    Net::SSLeay::EC_KEY_free($ecdh);
  }
  if ($opts{'verify_file'} || $opts{'verify_dir'}) {
    Net::SSLeay::CTX_load_verify_locations($ctx, $opts{'verify_file'} || '', $opts{'verify_dir'} || '') || die_with_error_stack("CTX_load_verify_locations failed");
  } elsif (!defined($opts{'verify_file'}) && !defined($opts{'verify_dir'})) {
    Net::SSLeay::CTX_set_default_verify_paths($ctx) || die_with_error_stack("CTX_set_default_verify_paths failed");
  }
  return $ctx;
}

sub freectx {
  my ($ctx) = @_;
  Net::SSLeay::CTX_free($ctx) if $ctx;
  return undef;
}

sub setdefaultctx {
  my ($ctx) = @_;
  freectx($sslctx);
  $sslctx = $ctx;
  return $sslctx;
}

sub tossl {
  local *S = shift @_;
  tie(*{\*S}, 'BSSSL', \*S, @_);
}

sub ssl_iseof {
  my ($ssl, $noselect, $socket) = @_;
  my $fn = Net::SSLeay::get_fd($ssl);
  return 0 unless defined $fn;
  if (!$noselect) {
    my $vec = '';
    vec($vec, $fn, 1) = 1;
    my $r = select($vec, undef, undef, 0);
    if (!defined($r) || $r < 0) {
      warn("select: $!\n");
      return 1;
    }
    return 0 unless $r;
  }
  # sigh. we need to find a better way to call recv on the file descriptor
  my $fd = $socket;
  return 0 unless $fd || open($fd, '<&', $fn);
  my $buf = '';
  my $r = recv($fd, $buf, 1, Socket::MSG_PEEK());
  if (!defined($r)) {
    warn("recv: $!\n");
    close($fd) unless $socket;
    return 1;
  }
  close($fd) unless $socket;
  return length($buf) ? 0 : 1;
}

# this assumes the socket is in non-block mode
sub ssl_connect_with_timeout {
  my ($ssl, $socket, $timeout) = @_;
  $timeout += time();
  while (1) {
    my $r = Net::SSLeay::connect($ssl);
    return if $r > 0;
    my $code = Net::SSLeay::get_error($ssl, $r);
    my $now = time();
    die("SSL_connect timeout\n") if $now >= $timeout;
    my $vec = '';
    vec($vec, fileno($socket), 1) = 1;
    if ($code == &Net::SSLeay::ERROR_WANT_WRITE) {
      $r = select(undef, $vec, undef, $timeout - $now);
    } elsif ($code == &Net::SSLeay::ERROR_WANT_READ) {
      $r = select($vec, undef, undef, $timeout - $now);
      die("SSL_connect EOF\n") if $r && ssl_iseof($ssl, 1, $socket);
    } else {
      die_with_error_stack("SSL_connect error ($code)");
    }
    die("select: $!\n") if !defined($r) || $r < 0;
    die("SSL_connect timeout\n") if time() >= $timeout;
  }
}

sub TIEHANDLE {
  my ($self, $socket, %opts) = @_;

  my $ctx = $opts{'ctx'} || $sslctx || setdefaultctx(newctx());
  my $ssl = Net::SSLeay::new($ctx) or die("SSL_new failed\n");
  Net::SSLeay::set_fd($ssl, fileno($socket));
  if ($opts{'keyfile'}) {
    Net::SSLeay::use_PrivateKey_file($ssl, $opts{'keyfile'}, &Net::SSLeay::FILETYPE_PEM) || die("PrivateKey $opts{'keyfile'} failed to load\n");
  }
  if ($opts{'certfile'}) {
    Net::SSLeay::use_certificate_chain_file($ssl, $opts{'certfile'}) || die("certificate $opts{'certfile'} failed to load\n");
  }
  my $mode = $opts{'mode'} || ($opts{'keyfile'} ? 'accept' : 'connect');
  my $cert_ok;
  my $verify = $opts{'verify'};
  if ($verify) {
    $verify = 'fail_unverified' if $mode eq 'connect' && $verify eq '1';	# sane default for client mode
    my $flags = &Net::SSLeay::VERIFY_PEER;
    $flags |= &Net::SSLeay::VERIFY_FAIL_IF_NO_PEER_CERT if $mode eq 'connect' || ($verify =~ /enforce_cert/);
    my $cb;
    if ($verify !~ /fail_unverified/) {
      $cb = sub { $cert_ok = $_[0] if !$_[0] || !defined($cert_ok); return 1 };
    } else {
      if ($mode eq 'connect') {
	$cb = undef; # can use the default handler
	$cert_ok = 1;
      } else {
        $cb = sub { $cert_ok = $_[0] if !$_[0] || !defined($cert_ok); return $_[0] };
      }
    }
    Net::SSLeay::set_verify($ssl, $flags, $cb);
  }
  if ($mode eq 'accept') {
    Net::SSLeay::accept($ssl) == 1 || die("SSL_accept error $!\n");
  } else {
    Net::SSLeay::set_tlsext_host_name($ssl, $opts{'sni'}) if $opts{'sni'} && defined(&Net::SSLeay::set_tlsext_host_name);
    if ($opts{'nonblocking'} || $opts{'connect_timeout'}) {
      ssl_connect_with_timeout($ssl, $socket, $opts{'connect_timeout'} || 300);
    } else {
      Net::SSLeay::connect($ssl) > 0 || die_with_error_stack("SSL_connect error");
    }
  }
  return bless [$ssl, $socket, \$cert_ok] if $verify;
  return bless [$ssl, $socket];
}

sub PRINT {
  my $sslr = shift;
  return WRITE($sslr, join($, || '', @_, $\ || ''));
}

sub READLINE {
  my ($sslr) = @_;
  return Net::SSLeay::ssl_read_until($sslr->[0]); 
}

sub READ {
  my ($sslr, undef, $len, $offset) = @_;
  my $buf = \$_[1];
  $! = 0;
  my ($r, $rv)  = Net::SSLeay::read($sslr->[0]);
  if ($rv <= 0) {
    my $code = Net::SSLeay::get_error($sslr->[0], $rv);
    return 0 if $code == &Net::SSLeay::ERROR_WANT_READ && ssl_iseof($sslr->[0]);
    $! = POSIX::EINTR if $code == &Net::SSLeay::ERROR_WANT_READ || $code == &Net::SSLeay::ERROR_WANT_WRITE;
  }
  return undef unless defined $r;
  return length($$buf = $r) unless defined $offset;
  my $bl = length($$buf);
  $$buf .= chr(0) x ($offset - $bl) if $offset > $bl;
  substr($$buf, $offset) = $r;
  return length($r);
}

sub WRITE {
  my ($sslr, $buf, $len, $offset) = @_;
  return $len unless $len;
  $! = 0;
  my $rv = Net::SSLeay::write($sslr->[0], substr($buf, $offset || 0, $len));
  if ($rv <= 0) {
    my $code = Net::SSLeay::get_error($sslr->[0], $rv);
    $! = POSIX::EINTR if $code == &Net::SSLeay::ERROR_WANT_READ || $code == &Net::SSLeay::ERROR_WANT_WRITE;
    return undef;
  }
  return $rv;
}

sub FILENO {
  my ($sslr) = @_;
  return Net::SSLeay::get_fd($sslr->[0]);
}

sub CLOSE {
  my ($sslr) = @_;
  if (tied($sslr->[1]) && tied($sslr->[1]) eq $sslr) {
    untie($sslr->[1]);
    close($sslr->[1]);
  } else {
    Net::SSLeay::free(splice(@$sslr, 0, 1, undef));
  }
  undef $sslr->[1];
}

sub UNTIE {
  my ($sslr) = @_;
  Net::SSLeay::free(splice(@$sslr, 0, 1, undef));
}

sub DESTROY {
  my ($sslr) = @_;
  UNTIE($sslr) if $sslr && $sslr->[0];
}

sub data_available {
  my ($sslr) = @_;
  my ($r, $rv) = Net::SSLeay::peek($sslr->[0], 1);
  if ($rv <= 0) {
    my $code = Net::SSLeay::get_error($sslr->[0], $rv);
    return 0 if $code == &Net::SSLeay::ERROR_WANT_READ || $code == &Net::SSLeay::ERROR_WANT_WRITE;
  }
  return defined($r) ? 1 : undef;
}

sub peerfingerprint {
  my ($sslr, $type) = @_;
  my $cert = Net::SSLeay::get_peer_certificate($sslr->[0]);
  return undef unless $cert;
  my $fp = Net::SSLeay::X509_get_fingerprint($cert, lc($type));
  Net::SSLeay::X509_free($cert);
  return undef unless $fp;
  $fp =~ s/://g;
  return lc($fp);
}

sub subjectdn {
  my ($sslr, $ignoreverify) = @_;
  if (!$ignoreverify) {
    my $cert_ok = @$sslr >= 3 ? ${$sslr->[2]} : 0;
    return undef unless $cert_ok;
  }
  my $cert = Net::SSLeay::get_peer_certificate($sslr->[0]);
  return undef unless $cert;
  my $subject = Net::SSLeay::X509_get_subject_name($cert);
  return undef unless $subject;
  return Net::SSLeay::X509_NAME_print_ex($subject, &Net::SSLeay::XN_FLAG_RFC2253);
}

1;
