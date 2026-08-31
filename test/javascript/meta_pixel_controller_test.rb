require "test_helper"

# Runs the Node suite next to this file, so the browser half of the pixel is
# covered by `bin/rails test` like everything else.
#
# The JavaScript is what decides how many PageViews go out, and a duplicate there
# is invisible to a request test: this is the only place that actually drives
# connect() the way Turbo does.
class MetaPixelControllerTest < ActiveSupport::TestCase
  SUITE = Rails.root.join("test/javascript/meta_pixel_controller_test.mjs")

  test "the Stimulus controller sends exactly one PageView per navigation" do
    skip "node is not installed" unless system("which node > /dev/null 2>&1")

    output = `cd #{Rails.root} && node --test #{SUITE} 2>&1`

    assert $?.success?, "the Meta Pixel Node suite failed:\n#{output}"
    assert_match(/# fail 0/, output)
  end
end
