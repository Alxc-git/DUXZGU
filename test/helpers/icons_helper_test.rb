require "test_helper"

class IconsHelperTest < ActionView::TestCase
  include IconsHelper

  test "every icon path is a whole path, not a fragment" do
    IconsHelper::ICON_PATHS.each do |name, paths|
      paths.each do |d|
        # A `%w[]` literal splits every path on its spaces, which turns one icon
        # into a dozen one-token paths that render as confetti. Real subpaths
        # start with a command and carry coordinates.
        assert_match(/\A[MmAaCcLlHhVvQqSsTtZz]/, d, "#{name}: path does not start with a command")
        assert d.length > 5, "#{name}: #{d.inspect} is too short to be a path"
      end
    end
  end

  test "icon renders one path element per subpath" do
    svg = icon("clock")

    assert_equal 2, svg.scan("<path").length
    assert_includes svg, 'viewBox="0 0 24 24"'
  end

  test "icon returns nothing for an unknown name" do
    assert_equal "", icon("not-an-icon")
  end

  test "star rating renders five stars" do
    assert_equal 5, star_rating(4.7).scan("<svg").length
  end
end
