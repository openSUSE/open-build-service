#
# Copyright (c) 2023 SUSE Inc.
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
# Create a ssh signature with the sign utility
#

package BSSSHSign;

use MIME::Base64 ();
use Digest::SHA ();

use BSUtil;
use BSConfiguration;

use strict;

our $sign_prg = '/usr/bin/sign';

sub armor {
  my ($in, $what) = @_; 
  my $ret = MIME::Base64::encode_base64($in, '');
  $ret =~ s/(.{70})/$1\n/g;
  $ret =~ s/\n$//s;
  return "-----BEGIN $what-----\n$ret\n-----END $what-----\n";
}

sub packargs {
  return pack('Na*' x scalar(@_), map {(length($_), $_)} @_);
}

sub hashmessage {
  my ($message, $hash) = @_;
  my $ctx;
  $ctx = Digest::SHA->new(256) if $hash eq 'sha256';
  $ctx = Digest::SHA->new(512) if $hash eq 'sha512';
  die("unsupported hash algorithm $hash\n") unless $ctx;
  $ctx->add($message);
  return $ctx->digest();
}

sub sshsign {
  my ($message, $namespace, $user, $hash, $sshpubkey) = @_;
  my ($pubkey_algo, $pubkey_data) = split(' ', $sshpubkey);
  die("bad pubkey\n") unless defined $pubkey_data;
  $pubkey_data = MIME::Base64::decode_base64($pubkey_data);
  die("unsupported pubkey algorithm $pubkey_algo\n") unless $pubkey_algo eq 'ssh-rsa';
  die("unsupported hash algorithm $hash\n") unless $hash eq 'sha256' || $hash eq 'sha512';
  my $tosign = 'SSHSIG'.packargs($namespace, '', $hash, hashmessage($message, $hash));
  my $sigdata = BSUtil::xsystem($tosign, $sign_prg, '-u', $user, '-h', $hash, '-O');
  my $sigalgo = $hash;
  $sigalgo =~ s/.../rsa-sha2-/;
  $sigdata = packargs($sigalgo, $sigdata);
  my $sig = 'SSHSIG'.pack('N', 1).packargs($pubkey_data, $namespace, '', $hash, $sigdata);
  return armor($sig, 'SSH SIGNATURE');
}

# perl -I. -MBSUtil -MBSPGP -MBSSSHSign -e 'print BSSSHSign::keydata2pubkey(BSPGP::pk2keydata(BSPGP::unarmor(readstr($ARGV[0]))))."\n"'
sub keydata2pubkey {
  my ($keydata, $userid) = @_;
  my $pubkey_algo;
  my $pubraw;
  my $algo = $keydata->{'algo'} || '?';
  if ($algo eq 'rsa') {
    $pubkey_algo = 'ssh-rsa';
    my ($n, $e) = map {$keydata->{'mpis'}->[$_]->{'data'}} (0, 1);
    $n = "\0$n" if ord($n) >= 128;
    $e = "\0$e" if ord($e) >= 128;
    $pubraw = packargs($pubkey_algo, $e, $n);
  } else {
    die("unsupported pubkey algo $algo\n");
  }
  $userid = 'user@localhost' unless defined $userid;
  return $pubkey_algo.' '.MIME::Base64::encode_base64($pubraw, '').($userid ne '' ? " $userid" : '');
}

1;
