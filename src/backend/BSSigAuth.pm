#
# Copyright (c) 2022 SUSE Inc.
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
# Signature authentification
#

package BSSigAuth;

use BSHTTP;
use BSUtil;

use MIME::Base64 ();

use strict;

sub justone {
  my ($signature, $key) = @_;
  return unless $signature->{$key};
  die("Signature authentification: more than one value for $key\n") unless @{$signature->{$key}} == 1;
  $signature->{$key} = $signature->{$key}->[0];
}

sub dosshsign {
  my ($state, $signdata, $keyfile, $namespace) = @_;
  die("no key file specified\n") unless $keyfile;
  my $out;
  if (ref($keyfile)) {
    $out = eval { $keyfile->($state, $signdata, $namespace) };
    die("Signature authentification: $@") if $@;
  } else {
    ($out) = BSUtil::xsystem($signdata, 'ssh-keygen', '-Y', 'sign', '-n', $namespace, '-f', $keyfile);
  }
  die("Signature authentification: bad ssh signature format\n") unless $out =~ s/.*-----BEGIN SSH SIGNATURE-----\n//s;
  die("Signature authentification: bad ssh signature format\n") unless $out =~ s/-----END SSH SIGNATURE-----.*//s;
  my $sig = MIME::Base64::decode_base64($out);
  die("Signature authentification: bad ssh signature\n") unless substr($sig, 0, 6) eq 'SSHSIG';
  return $sig;
}

sub authenticator_function {
  my ($state, $param, $wwwauthenticate) = @_;
  return $state->{'auth'} if !$wwwauthenticate;         # return last auth
  delete $state->{'auth'};
  my $keyid = $state->{'keyid'};
  my %auth = BSHTTP::parseauthenticate($wwwauthenticate);
  my $signature = $auth{'signature'};
  return '' unless $signature;
  justone($signature, $_) for 'headers', 'realm', 'algorithm';
  my $headers = $signature->{'headers'} || '(created)';
  my $created = time();
  my $tosign = '';
  for my $h (split(/ /, $headers)) {
    if ($h eq '(created)') {
      $tosign .= "(created): $created\n";
    } else {
      die("Signature authentification: unsupported header element: $h\n");
    }
  }
  die("Signature authentification: nothing to sign?\n") unless $tosign;
  chop $tosign;
  my $algorithm = $state->{'algorithm'};
  die("Signature authentification: algorithm mismatch $signature->{'algorithm'} - $algorithm\n") if $signature->{'algorithm'} && $signature->{'algorithm'} ne $algorithm;
  my $sig;
  if ($algorithm eq 'ssh') {
    $sig = dosshsign($state, $tosign, $state->{'keyfile'}, $signature->{'realm'} || '');
  } else {
    die("Signature authentification: unsupported algorithm '$algorithm'\n");
  }
  $sig = MIME::Base64::encode_base64($sig, '');
  die("bad keyid '$keyid'\n") if $keyid =~ /\"/;
  my $auth = "Signature keyId=\"$keyid\",algorithm=\"$algorithm\",headers=\"$headers\",created=$created,signature=\"$sig\"";
  $state->{'auth'} = $auth;
  return $auth;
}

sub generate_authenticator {
  my ($keyid, %opts) = @_;
  my $state = { 'keyid' => $keyid, 'algorithm' => 'ssh', %opts };
  return sub { authenticator_function($state, @_) };
}

1;
