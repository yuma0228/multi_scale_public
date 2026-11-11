# frozen_string_literal: true

require "test_helper"
# DSL : domain scpecific language
# rule, 

class TestMyHello < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MyHello::VERSION
  end

  def test_it_does_something_useful
    assert true
  end

  def test_it_outputs_hello
    assert_output("Hello, bob.\n") do
      MyHello.greeting("bob")
    end
  end

  def test_greeting_object_outputs_hello_with_name
    greeting = MyHello::Greeting.new("bob")

    assert_output("Hello, bob.\n") do
      greeting.call
    end
  end

end

class TestMyHelloCLI < Minitest::Test
  def test_parses_name_option
    assert_output("Hello, bob.\n") do
      MyHello::CLI.start(["greeting", "--name", "bob"])
    end
  end

  def test_parses_short_name_option
    assert_output("Hello, bob.\n") do
      MyHello::CLI.start(["greeting", "-n", "bob"])
    end
  end

  def test_requires_name_option
    _stdout, stderr = capture_io do
      MyHello::CLI.start(["greeting"])
    end

    assert_includes stderr, "No value provided for required options '--name'"
  end
end
