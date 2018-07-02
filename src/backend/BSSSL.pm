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

sub initctx {
  my ($keyfile, $certfile) = @_;
  Net::SSLeay::load_error_strings();
  Net::SSLeay::SSLeay_add_ssl_algorithms();
  Net::SSLeay::randomize();
  $sslctx = Net::SSLeay::CTX_new() or die("CTX_new failed!\n");
  Net::SSLeay::CTX_set_options($sslctx, &Net::SSLeay::OP_ALL);
  if ($keyfile) {
    Net::SSLeay::CTX_use_RSAPrivateKey_file($sslctx, $keyfile, &Net::SSLeay::FILETYPE_PEM) || die("RSAPrivateKey $keyfile failed\n");
  }
  if ($certfile) {
    Net::SSLeay::CTX_use_certificate_file($sslctx, $certfile, &Net::SSLeay::FILETYPE_PEM) || die("certificate $keyfile failed\n");
  }
  if (defined &Net::SSLeay::CTX_set_tmp_ecdh) {
    my $curve = Net::SSLeay::OBJ_txt2nid('prime256v1');
    my $ecdh  = Net::SSLeay::EC_KEY_new_by_curve_name($curve);
    Net::SSLeay::CTX_set_tmp_ecdh($sslctx, $ecdh);
    Net::SSLeay::EC_KEY_free($ecdh);
  }
}

sub freectx {
  Net::SSLeay::CTX_free($sslctx);
  undef $sslctx;
}

sub tossl {
  tie(*{$_[0]}, 'BSSSL', @_);
}

sub TIEHANDLE {
  my ($self, $socket, $keyfile, $certfile, $forceconnect) = @_;

  initctx() unless $sslctx;
  my $ssl = Net::SSLeay::new($sslctx) or die("SSL_new failed\n");
  Net::SSLeay::set_fd($ssl, fileno($socket));
  if ($keyfile) {
    Net::SSLeay::use_RSAPrivateKey_file($ssl, $keyfile, &Net::SSLeay::FILETYPE_PEM) || die("RSAPrivateKey $keyfile failed\n");
  }
  if ($certfile) {
    Net::SSLeay::use_certificate_file($ssl, $certfile, &Net::SSLeay::FILETYPE_PEM) || die("certificate $certfile failed\n");
  }
  if (defined($keyfile) && !$forceconnect) {
    Net::SSLeay::accept($ssl) == 1 || die("SSL_accept\n");
  } else {
    Net::SSLeay::connect($ssl) || die("SSL_connect");
  }
  return bless [$ssl, $socket];
}

sub PRINT {
  my $sslr = shift;
  my $r = 0;
  for my $msg (@_) {
    next unless defined $msg;
    $r = Net::SSLeay::write($sslr->[0], $msg) or last;
  }
  return $r;
}

sub READLINE {
  my ($sslr) = @_;
  return Net::SSLeay::ssl_read_until($sslr->[0]); 
}

sub READ {
  my ($sslr, undef, $len, $offset) = @_;
  my $buf = \$_[1];
  my ($r, $rv)  = Net::SSLeay::read($sslr->[0]);
  if ($rv && $rv < 0) {
    my $code = Net::SSLeay::get_error($sslr->[0], $rv);
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
  return Net::SSLeay::write($sslr->[0], substr($buf, $offset || 0, $len)) ? $len : undef;
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
    Net::SSLeay::free($sslr->[0]);
    undef $sslr->[0];
  }
  undef $sslr->[1];
}

sub UNTIE {
  my ($sslr) = @_;
  Net::SSLeay::free($sslr->[0]);
  undef $sslr->[0];
}

sub DESTROY {
  my ($sslr) = @_;
  UNTIE($sslr) if $sslr && $sslr->[0];
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

1;
