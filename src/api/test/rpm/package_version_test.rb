require 'rpm'

class Rpm::PackageVersionTest < Minitest::Test
  def test_comparison_of_major_versions
    assert_equal(0, Rpm::PackageVersion.new('1') <=> Rpm::PackageVersion.new('1'))
    assert_equal(1, Rpm::PackageVersion.new('2') <=> Rpm::PackageVersion.new('1'))
    assert_equal(-1, Rpm::PackageVersion.new('1') <=> Rpm::PackageVersion.new('2'))

    assert_equal(1, Rpm::PackageVersion.new('12') <=> Rpm::PackageVersion.new('3'))
    assert_equal(-1, Rpm::PackageVersion.new('3') <=> Rpm::PackageVersion.new('12'))
  end

  def test_comparison_of_minor_versions
    assert_equal(0, Rpm::PackageVersion.new('1.1') <=> Rpm::PackageVersion.new('1.1'))
    assert_equal(1, Rpm::PackageVersion.new('1.2') <=> Rpm::PackageVersion.new('1.1'))
    assert_equal(-1, Rpm::PackageVersion.new('1.1') <=> Rpm::PackageVersion.new('1.2'))

    assert_equal(1, Rpm::PackageVersion.new('1.12') <=> Rpm::PackageVersion.new('1.3'))
    assert_equal(-1, Rpm::PackageVersion.new('1.3') <=> Rpm::PackageVersion.new('1.12'))
  end

  def test_comparison_of_nano_versions
    assert_equal(0, Rpm::PackageVersion.new('1.1.1.1') <=> Rpm::PackageVersion.new('1.1.1.1'))
    assert_equal(1, Rpm::PackageVersion.new('1.1.1.2') <=> Rpm::PackageVersion.new('1.1.1.1'))
    assert_equal(-1, Rpm::PackageVersion.new('1.1.1.1') <=> Rpm::PackageVersion.new('1.1.1.2'))

    assert_equal(1, Rpm::PackageVersion.new('1.1.1.12') <=> Rpm::PackageVersion.new('1.1.1.3'))
    assert_equal(-1, Rpm::PackageVersion.new('1.1.1.3') <=> Rpm::PackageVersion.new('1.1.1.12'))
  end

  def test_comparison_of_versions_with_different_lengths
    assert_equal(1, Rpm::PackageVersion.new('1.0') <=> Rpm::PackageVersion.new('1'))
    assert_equal(-1, Rpm::PackageVersion.new('1') <=> Rpm::PackageVersion.new('1.0'))

    assert_equal(1, Rpm::PackageVersion.new('1.0.0') <=> Rpm::PackageVersion.new('1.0'))
    assert_equal(-1, Rpm::PackageVersion.new('1.0') <=> Rpm::PackageVersion.new('1.0.0'))
  end

  def test_comparison_of_prerelease_versions
    assert_equal(0, Rpm::PackageVersion.new('1.0b1') <=> Rpm::PackageVersion.new('1.0b1'))
    assert_equal(1, Rpm::PackageVersion.new('1.0.0') <=> Rpm::PackageVersion.new('1.0b1'))
    assert_equal(-1, Rpm::PackageVersion.new('1.0b1') <=> Rpm::PackageVersion.new('1.0.0'))
    assert_equal(1, Rpm::PackageVersion.new('1.0b1') <=> Rpm::PackageVersion.new('1.0'))
    assert_equal(-1, Rpm::PackageVersion.new('1.0') <=> Rpm::PackageVersion.new('1.0b1'))

    assert_equal(0, Rpm::PackageVersion.new('1.0.b1') <=> Rpm::PackageVersion.new('1.0.b1'))
    assert_equal(1, Rpm::PackageVersion.new('1.0.0') <=> Rpm::PackageVersion.new('1.0.b1'))
    assert_equal(-1, Rpm::PackageVersion.new('1.0.b1') <=> Rpm::PackageVersion.new('1.0.0'))
    assert_equal(1, Rpm::PackageVersion.new('1.0.b1') <=> Rpm::PackageVersion.new('1.0'))
    assert_equal(-1, Rpm::PackageVersion.new('1.0') <=> Rpm::PackageVersion.new('1.0.b1'))
  end

  def test_comparison_with_nil
    assert_equal(0, Rpm::PackageVersion.new(nil) <=> Rpm::PackageVersion.new(nil))
    assert_equal(1, Rpm::PackageVersion.new('1') <=> Rpm::PackageVersion.new(nil))
    assert_equal(-1, Rpm::PackageVersion.new(nil) <=> Rpm::PackageVersion.new('1'))
  end
end
