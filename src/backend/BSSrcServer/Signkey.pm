# Copyright (c) 2018 SUSE LLC
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

package BSSrcServer::Signkey;

use strict;

use BSConfiguration;
use BSUtil;
use BSPGP;
use BSX509;
use BSASN1;

my $srcrep = "$BSConfig::bsdir/sources";
my $uploaddir = "$srcrep/:upload";

my $keyalgo = 'rsa@2048';
my $keyexpiry = 800;

sub createkey {
  my ($projid) = @_;
  die("don't know how to create a key\n") unless $BSConfig::sign;
  mkdir_p($uploaddir);
  unlink("$uploaddir/signkey.$$");
  my @keyargs = ($keyalgo, $keyexpiry);
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '-P', "$uploaddir/signkey.$$";
  #push @signargs, '-h', 'sha256';
  my $obsname = $BSConfig::obsname || 'build.opensuse.org';
  my $pubkey = '';
  local *F;
  open(F, '-|', $BSConfig::sign, @signargs, '-g', @keyargs, "$projid OBS Project", "$projid\@$obsname") || die("$BSConfig::sign: $!\n");
  1 while sysread(F, $pubkey, 4096, length($pubkey));
  close(F) || die("$BSConfig::sign: $?\n");
  my $signkey = readstr("$uploaddir/signkey.$$", 1);
  unlink("$uploaddir/signkey.$$");
  die("sign did not create signkey\n") unless $signkey;
  die("sign did not return pubkey\n") unless $pubkey;
  return ($pubkey, $signkey);
}

sub extendkey {
  my ($projid, $pubkeyfile, $signkeyfile) = @_;
  die("don't know how to extend a key\n") unless $BSConfig::sign;
  die("project does not have a key\n") unless -s $pubkeyfile;
  die("project does not have a signkey\n") unless -s $signkeyfile;
  my @keyargs = ($keyexpiry);
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '-P', $signkeyfile;
  my $pubkey = '';
  local *F;
  open(F, '-|', $BSConfig::sign, @signargs, '-x', @keyargs, $pubkeyfile) || die("$BSConfig::sign: $!\n");
  1 while sysread(F, $pubkey, 4096, length($pubkey));
  close(F) || die("$BSConfig::sign: $?\n");
  die("sign did not return pubkey\n") unless $pubkey;
  return $pubkey;
}

sub pubkey2sslcert {
  my ($projid, $pubkeyfile, $signkeyfile, $signtype) = @_;
  die("don't know how to generate a ssl cert\n") unless $BSConfig::sign;
  die("project does not have a key\n") unless -s $pubkeyfile;
  die("project does not have a signkey\n") unless -s $signkeyfile;
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '--signtype', $signtype if $BSConfig::sign_type && $signtype;
  push @signargs, '-P', $signkeyfile;
  my $cert = '';
  eval {
    $cert = BSUtil::xsystem(undef, $BSConfig::sign, @signargs, '-C', $pubkeyfile);
  };
  if ($@) {
    die("Need an RSA key for openssl signing, please create a new key for $projid\n") if $@ =~ /not an RSA private key/i;
    die($@);
  }
  return $cert;
}

sub getdefaultcert {
  my ($projid, $signtype) = @_;
  return undef unless $BSConfig::sign;
  my $cert = '';
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  push @signargs, '--signtype', $signtype if $BSConfig::sign_type && $signtype;
  local *F;
  open(F, '-|', $BSConfig::sign, @signargs, '-C') || die("$BSConfig::sign: $!\n");
  1 while sysread(F, $cert, 4096, length($cert));
  close(F) || die("$BSConfig::sign: $?\n");
  return $cert;
}


sub getdefaultpubkey {
  my ($projid) = @_;
  return undef unless $BSConfig::sign;
  my @signargs;
  push @signargs, '--project', $projid if $BSConfig::sign_project;
  local *S;
  open(S, '-|', $BSConfig::sign, @signargs, '-p') || die("$BSConfig::sign: $!\n");
  my $pk = '';
  1 while sysread(S, $pk, 4096, length($pk));
  close(S) || die("$BSConfig::sign: $?\n");
  return $pk;
}

sub pubkeyinfo {
  my ($pk) = @_;

  my ($algo, $curve, $keysize);
  my $fingerprint;
  my $expire;
  my $userid;
  eval {
    my $pku = BSPGP::unarmor($pk);
    my $d = BSPGP::pk2keydata($pku);
    $algo = $d->{'algo'} if $d->{'algo'};
    $curve = $d->{'curve'} if $d->{'curve'};
    $keysize = $d->{'keysize'} if $d->{'keysize'};
    eval { $fingerprint = BSPGP::pk2fingerprint($pku) };
    eval { $expire = BSPGP::pk2expire($pku) };
    eval { $userid = BSPGP::pk2userid($pku) };
  };
  warn($@) if $@;
  my $pubkey = {};
  $pubkey->{'algo'} = $algo if $algo;
  $pubkey->{'keysize'} = $keysize if $keysize;
  $pubkey->{'userid'} = $userid if defined $userid;
  if ($fingerprint) {
    $pubkey->{'keyid'} = substr($fingerprint, -16, 16);
    $fingerprint =~ s/(....)/$1 /g;
    $fingerprint =~ s/ $//;
    $pubkey->{'fingerprint'} = $fingerprint;
  }
  $pubkey->{'expires'} = $expire if $expire;
  return $pubkey;
}

sub subjectpublickeyinfo {
  my ($pk, $isder) = @_;
  my ($algo, $curve, $keysize);
  my $fingerprint;
  eval {
    my $pku = $isder ? $pk : BSASN1::pem2der($pk, 'PUBLIC KEY');
    my $d = BSX509::pubkey2keydata($pku);
    $algo = $d->{'algo'} if $d->{'algo'};
    $curve = $d->{'curve'} if $d->{'curve'};
    $keysize = $d->{'keysize'} if $d->{'keysize'};
    $fingerprint = unpack('H*', BSX509::generate_key_id($pku));
  };
  warn($@) if $@;
  my $pubkey = {};
  $pubkey->{'algo'} = $algo if $algo;
  $pubkey->{'curve'} = $curve if $curve;
  $pubkey->{'keysize'} = $keysize if $keysize;
  if ($fingerprint) {
    $fingerprint =~ s/(....)/$1 /g;
    $fingerprint =~ s/ $//;
    $pubkey->{'fingerprint'} = $fingerprint;
  }
  return $pubkey;
}

sub certinfo {
  my ($cert) = @_;
  my $info  = {};
  eval {
    my $der = BSASN1::pem2der($cert, 'CERTIFICATE');
    my $tbscert = (BSASN1::unpack_sequence($der, undef, [ $BSASN1::CONS | $BSASN1::SEQUENCE, -1]))[0];
    my (undef, $serial, $sigalgo, $issuer, $validity, $subject, $subjectkeyinfo) = BSASN1::unpack_sequence($tbscert, undef, $BSX509::tbscertificate_tags);
    $serial = BSASN1::unpack_integer_mpi($serial);
    $info->{'serial'} = length($serial) ? '0x' . unpack('H*', $serial) : '0x0';
    ($info->{'begins'}, $info->{'expires'}) = BSX509::unpack_validity($validity);
    my $pkinfo = subjectpublickeyinfo($subjectkeyinfo, 1);
    defined($pkinfo->{$_}) && ($info->{$_} = $pkinfo->{$_}) for qw{algo keysize fingerprint};
    $info->{'subject'} = BSX509::dn2str($subject);
    $info->{'issuer'} = BSX509::dn2str($issuer) if $issuer ne $subject;
  };
  warn($@) if $@;
  return $info;
}

1;
