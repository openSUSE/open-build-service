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

use Socket;
use Net::SSLeay;

use strict;

my $sslctx;

sub initctx {
  my ($keyfile, $certfile) = @_;
  Net::SSLeay::load_error_strings();
  Net::SSLeay::SSLeay_add_ssl_algorithms();
  Net::SSLeay::randomize();
  $sslctx = Net::SSLeay::CTX_new () or die("CTX_new failed!\n");
  Net::SSLeay::CTX_set_options($sslctx, &Net::SSLeay::OP_ALL);
  if ($keyfile) {
    Net::SSLeay::CTX_use_RSAPrivateKey_file($sslctx, $keyfile, &Net::SSLeay::FILETYPE_PEM) || die("RSAPrivateKey $keyfile failed\n");
  }
  if ($certfile) {
    Net::SSLeay::CTX_use_certificate_file($sslctx, $certfile, &Net::SSLeay::FILETYPE_PEM) || die("certificate $keyfile failed\n");
  }
}

sub freectx {
  Net::SSLeay::CTX_free($sslctx);
}

sub tossl {
  local *S = shift @_;
  tie(*S, 'BSSSL', *S, @_);
}

sub TIEHANDLE {
  my ($self, $socket, $keyfile, $certfile) = @_;

  initctx() unless $sslctx;
  my $ssl = Net::SSLeay::new($sslctx) or die("SSL_new failed\n");
  Net::SSLeay::set_fd($ssl, fileno($socket));
  if (defined($keyfile)) {
    if ($keyfile ne '') {
      Net::SSLeay::use_RSAPrivateKey_file($ssl, $keyfile, &Net::SSLeay::FILETYPE_PEM) || die("RSAPrivateKey $keyfile failed\n");
    }
    if ($certfile ne '') {
      Net::SSLeay::use_certificate_file ($ssl, $certfile, &Net::SSLeay::FILETYPE_PEM) || die("certificate $certfile failed\n");
    }
    Net::SSLeay::accept($ssl) == 1 || die("SSL_accept\n");
  } else {
    Net::SSLeay::connect($ssl) || die("SSL_connect");
  }
  return bless \$ssl;
}

sub PRINT {
  my $sslr = shift;
  my $r = 0;
  for my $msg (@_) {
    next unless defined $msg;
    $r = Net::SSLeay::write($$sslr, $msg) or last;
  }
  return $r;
}

sub READLINE {
  my ($sslr) = @_;
  return Net::SSLeay::ssl_read_until($$sslr); 
}

sub READ {
  my ($sslr, undef, $len, $offset) = @_;
  my $buf = \$_[1];
  my $r = Net::SSLeay::read($$sslr, $len);
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
  return Net::SSLeay::write($$sslr, substr($buf, $offset || 0, $len)) ? $len : undef;
}

sub FILENO {
  my ($sslr) = @_;
  return Net::SSLeay::get_fd($$sslr);
}

sub CLOSE {
  my ($sslr) = @_;
  Net::SSLeay::free($$sslr);
}

1;
