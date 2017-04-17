module Rpm
  ##
  # The Rpm::PackageVersion class processes string versions into comparable values.
  #
  # Comparison is done based on the logic used in /usr/lib/rpm/rpmsort.
  #
  # Examples:
  #
  #   Rpm::PackageVersion.new('3.0') > Rpm::PackageVersion.new('2.0')
  #   => true
  #
  #   Rpm::PackageVersion.new('2.1') > Rpm::PackageVersion.new('2.0')
  #   => true
  #
  #   Rpm::PackageVersion.new('2.0.0') > Rpm::PackageVersion.new('2.0.a1')
  #   => true
  #
  #   Rpm::PackageVersion.new('2.0.a1') > Rpm::PackageVersion.new('2.0')
  #   => true
  #
  class PackageVersion
    include Comparable

    def initialize(version)
      @version = version.to_s.dup
    end

    # This method mimics the version comparison logic from /usr/lib/rpm/rpmsort.
    def <=> other                                          # sub _rpm_cmp {
      s1 = _version                                        #     my ($s1, $s2) = @_;
      s2 = other._version

      return 0 if s1.blank? && s2.blank?                   #     return defined $s1 <=> defined $s2
      return -1 if s1.blank?                               #         unless defined $s1 && defined $s2;
      return 1 if s2.blank?

      r = 0                                                #     my ($r, $x1, $x2);
      until (r != 0) do                                    #     do {
        s1 = s1.sub(/^[^a-zA-Z0-9]+/, '')                  #         $s1 =~ s/^[^a-zA-Z0-9]+//;
        s2 = s2.sub(/^[^a-zA-Z0-9]+/, '')                  #         $s2 =~ s/^[^a-zA-Z0-9]+//;

        if (s1 =~ /^\d/ || s2 =~ /^\d/)                    #         if ($s1 =~ /^\d/ || $s2 =~ /^\d/) {
          s1 =~ /^(0*(\d*))/                               #             $s1 =~ s/^(0*(\d*))//;  $x1 = $2;
          return -1 if $1.blank?                           #             return -1 if $1 eq '';
          x1 = $2
          s1 = s1.sub(/^(0*(\d*))/, '')

          s2 =~ /^(0*(\d*))/                               #             $s2 =~ s/^(0*(\d*))//;  $x2 = $2;
          return 1 if $1.blank?                            #             return 1 if $1 eq '';
          x2 = $2
          s2 = s2.sub(/^(0*(\d*))/, '')

          r = (x1.to_i <=> x2.to_i)                        #             $r = length $x1 <=> length $x2 || $x1 cmp $x2;
        else                                               #         } else {
          s1 =~ /^([a-zA-Z]*)/                             #             $s1 =~ s/^([a-zA-Z]*)//;  $x1 = $1;
          x1 = $1;
          s1 = s1.sub(/^([a-zA-Z]*)/, '')

          s2 =~ /^([a-zA-Z]*)/                             #             $s2 =~ s/^([a-zA-Z]*)//;  $x2 = $1;
          x2 = $1;
          s2 = s2.sub(/^([a-zA-Z]*)/, '')

          return 0 if x1.blank? && x2.blank?               #             return 0
                                                           #                 if $x1 eq '' && $x2 eq '';
          r = (x1 <=> x2)                                  #             $r = $x1 cmp $x2;
        end                                                #         }
      end                                                  #     } until $r;

      r                                                    # return $r;
    end                                                    # }

    protected

    def _version
      @version
    end
  end
end
