require "test_helper"

class StemplTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Stempl::VERSION
  end
end
