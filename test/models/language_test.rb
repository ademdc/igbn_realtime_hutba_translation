require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "Bosnian khutbahs are recognised as Bosnian, Croatian or Serbian" do
    assert_equal %w[bs hr sr], Language.source_hints("bs")
    assert_equal %w[sq], Language.source_hints("sq")
  end

  test "listeners in the imam's language get the transcript" do
    assert Language.same_as_source?("de", "de")
    assert_not Language.same_as_source?("de", "bs")
  end

  test "Arabic reads right to left" do
    assert_equal "rtl", Language.direction("ar")
    assert_equal "ltr", Language.direction("sq")
  end
end
