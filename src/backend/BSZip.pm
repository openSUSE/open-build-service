################################################################
#
# Copyright (c) 2022 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 or 3 as
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

package BSZip;

use strict;

sub readbytes {
  my ($handle, $size, $pos) = @_;
  die("zip_list: file too small\n") if defined($pos) && $pos < 0;
  return '' if $size == 0;
  die("zip readbytes: invalid size $size\n") if $size < 0 || $size >= 0x1000000;
  seek($handle, $pos, 0) || die("seek: $!\n") if defined($pos);
  my $d;
  my $r = read($handle, $d, $size);
  die("zip read: $!\n") unless defined $r;
  die("zip read: unexpeced EOF ($r != $size)\n") unless $r == $size;
  return $d;
}

sub quadit {
  die("quad overflow\n") if $_[1] >= 65536;
  $_[0] = $_[0] + $_[1] * 65536 * 65536;
}

sub extract_stored {
  my ($handle, $size, $csize, $writer) = @_;
  while ($size > 0) {
    my $chunksize = $size > 65536 ? 65536 : $size;
    $writer->(readbytes($handle, $chunksize));
    $size -= $chunksize;
  }
}

sub extract_inflate {
  my ($handle, $size, $csize, $writer) = @_;
  return unless $size > 0;
  require Compress::Raw::Zlib unless defined &Compress::Raw::Zlib::Inflate::new;
  my ($decomp, $status) = Compress::Raw::Zlib::Inflate->new('-WindowBits' => -Compress::Raw::Zlib::MAX_WBITS(), '-Bufsize' => 65536);
  die("Compress::Raw::Zlib::Inflate::new failed\n") unless $decomp && $status == Compress::Raw::Zlib::Z_OK();
  while ($size > 0 || $csize > 0) {
    die("unexpected EOF\n") unless $csize > 0;
    my $chunksize = $csize > 65536 ? 65536 : $csize;
    my $chunk = readbytes($handle, $chunksize);
    $csize -= $chunksize;
    my $infchunk = '';
    ($status) = $decomp->inflate($chunk, $infchunk);
    die("decompression error\n") unless $status == Compress::Raw::Zlib::Z_OK() || $status == Compress::Raw::Zlib::Z_STREAM_END();
    die("decompression returned too much data\n") if length($infchunk) > $size;
    $writer->($infchunk) if length($infchunk);
    $size -= length($infchunk);
    last if $status == Compress::Raw::Zlib::Z_STREAM_END();
  }
  die("decompressed returned too few data\n") if $size;
}

sub extract {
  my ($handle, $ent, %opts) = @_;
  die("cannot extract this type of entry\n") if defined($ent->{'ziptype'}) && $ent->{'ziptype'} != 8 && $ent->{'ziptype'} != 10;
  my $data = '';
  return $data if $ent->{'size'} == 0;
  my $writer = $opts{'writer'} || sub { $data .= $_[0] };
  die("missing local header offset\n") unless defined $ent->{'lhdroffset'};
  my $lfh = readbytes($handle, 30, $ent->{'lhdroffset'});
  my ($lfh_magic, $lfh_vneed, $lfh_bits, $lfh_comp, $lfh_time, $lfh_date, $lfh_crc, $lfh_csize, $lfh_size, $lfh_fnsize, $lfh_extrasize) = unpack('VvvvvvVVVvv', $lfh);
  die("missing local file header\n") unless $lfh_magic == 0x04034b50;
  die("$ent->{'name'}: cannot extract encrypted files\n") if $lfh_bits & 1;
  readbytes($handle, $lfh_fnsize + $lfh_extrasize);	# verify file name?
  # can't use lfh size values because they may be in the trailing data descriptor
  if ($lfh_comp == 8) {
    extract_inflate($handle, $ent->{'size'}, $ent->{'csize'}, $writer);
  } elsif ($lfh_comp == 0) {
    extract_stored($handle, $ent->{'size'}, $ent->{'csize'}, $writer);
  } else {
    die("$ent->{'name'}: unsupported compression type $lfh_comp\n");
  }
  return $data;
}

sub list {
  my ($handle) = @_;
  my @s = stat($handle);
  die("zip_list: $!\n") unless @s;
  die("zip_list: only files supported\n") unless -f _;
  my $zipsize = $s[7];
  my $eocd = readbytes($handle, 22, $zipsize - 22);
  my ($eocd_magic, $eocd_disk, $eocd_cddisk, $eocd_cdcnt, $eocd_tcdcnt, $cd_size, $cd_offset, $eocd_commentsize) = unpack('VvvvvVVv', $eocd);
  if ($eocd_magic != 0x06054b50 || $eocd_commentsize != 0) {
    die("not a zip archive\n") unless $zipsize > 256 + 22;
    $eocd = readbytes($handle, 22 + 256, $zipsize - (22 + 256));
    die("not a zip archive\n") unless $eocd =~ /\A(.*)PK\005\006/s;
    $eocd = substr($eocd, length($1));
    die("not a zip archive\n") unless length($eocd) > 22;
    my $commentsize = length($eocd) - 22;
    ($eocd_magic, $eocd_disk, $eocd_cddisk, $eocd_cdcnt, $eocd_tcdcnt, $cd_size, $cd_offset, $eocd_commentsize) = unpack('VvvvvVVv', $eocd);
    die("not a zip archive\n") unless $eocd_magic == 0x06054b50 && $eocd_commentsize == $commentsize;
    $zipsize -= $commentsize;
  }
  if ($eocd_cdcnt == 0xffff || $eocd_tcdcnt == 0xffff || $cd_size == 0xffffffff || $cd_offset == 0xffffffff) {
    my $eocd64l = readbytes($handle, 20, $zipsize - 42);
    my ($eocd64l_magic, $eocd64l_cddisk, $eocd64_offset, $eocd64_offset_hi, $eocd64l_ndisk) = unpack('VVVVV', $eocd64l);
    die("missing end of central directory locator\n") unless $eocd64l_magic == 0x07064b50;
    quadit($eocd64_offset, $eocd64_offset_hi);
    die("multidisc zip archive\n") unless $eocd64l_cddisk == 0;
    die("invalid eocd64 offset\n") if $eocd64_offset > $zipsize - (20 + 22) || $zipsize - (20 + 22) - $eocd64_offset >= 0x10000 || $zipsize - (20 + 22) - $eocd64_offset < 56;
    $eocd = readbytes($handle, 56, $eocd64_offset);
    my ($eocd_cdcnt_hi, $eocd_tcdcnt_hi, $cd_offset_hi, $cd_size_hi);
    ($eocd_magic, undef, undef, undef, undef, $eocd_disk, $eocd_cddisk, $eocd_cdcnt, $eocd_cdcnt_hi, $eocd_tcdcnt, $eocd_tcdcnt_hi, $cd_size, $cd_size_hi, $cd_offset, $cd_offset_hi) = unpack('VVVvvVVVVVVVVVV');
    die("missing zip64 end of central directory record\n") unless $eocd_magic == 0x06064b50;
    quadit($eocd_cdcnt, $eocd_cdcnt_hi);
    quadit($eocd_tcdcnt, $eocd_tcdcnt_hi);
    quadit($cd_offset, $cd_offset_hi);
    die("invalid cd offset\n") if $cd_offset >= $eocd64_offset;
    die("central directory size mismatch\n") if $cd_size != $eocd64_offset - $cd_offset;
  } else {
    die("central directory size mismatch\n") if $cd_size != $zipsize - 22 - $cd_offset;
  }
  die("multidisc zip archive\n") unless $eocd_disk == 0 && $eocd_cddisk == 0;
  die("central directory too big\n") if $cd_size >= 0x1000000;
  my $left = $cd_size;
  my @l;
  while ($left > 0) {
    die("bad directory entry\n") if $left < 46;
    my $ent = readbytes($handle, 46, !@l ? $cd_offset : undef);
    my ($ent_magic, $ent_vmade, $ent_vneed, $ent_bits, $ent_comp, $ent_time, $ent_date, $ent_crc, $ent_csize, $ent_size, $ent_fnsize, $ent_extrasize, $ent_commentsize, $ent_diskno, $ent_iattr, $ent_xattr, $ent_lhdr) = unpack('VvvvvvvVVVvvvvvVV', $ent);
    die("bad directory entry\n") if $left < 46 + $ent_fnsize + $ent_extrasize + $ent_commentsize;
    my $name = readbytes($handle, $ent_fnsize);
    my $extra = readbytes($handle, $ent_extrasize);
    my $comment = readbytes($handle, $ent_commentsize);
    my $ziptype;
    my $ent_system = $ent_vmade >> 8;
    my $ent_mode;
    if ($ent_system == 3) {
      $ziptype = $ent_xattr >> 28;
      $ent_mode = ($ent_xattr >> 16) & 07777;
    } else {
      $ziptype = 8;
      $ziptype = 4 if $name =~ /\/$/;
      $ent_mode = $ziptype == 8 ? 0644 : 0755;
      $ent_mode &= 0555 if $ent_system == 0 && ($ent_xattr  & 1) != 0;
    }
    $name =~ s/\/+$//;
    $name =~ s/^\/+//;
    $name = '.' if $name eq '';
    push @l, { 'name' => $name, 'size' => $ent_size, 'csize' => $ent_csize, 'comp' => $ent_comp, 'lhdroffset' => $ent_lhdr , 'extra' => $extra, 'comment' => $comment, 'bits' => $ent_bits, 'ziptype' => $ziptype, 'mode' => $ent_mode, 'crc' => $ent_crc };
    $left -= 46 + $ent_fnsize + $ent_extrasize + $ent_commentsize;
  }
  return \@l;
}

1;
