defmodule Animina.BirthdayValidatorTest do
  use Animina.DataCase, async: true

  alias Animina.BirthdayValidator

  describe "Tests for the Birthday Validator" do
    test "A valid birthday is returned as a date" do
      assert {:ok, ~D[1995-08-15]} = BirthdayValidator.validate_birthday("15.08.95")
    end

    test "An invalid day for the given month returns an error" do
      assert {:error, "Invalid day for the given month."} =
               BirthdayValidator.validate_birthday("32.01.21")
    end

    test "A birthday in the future returns an error" do
      assert {:error, "Birthday cannot be in the future."} =
               BirthdayValidator.validate_birthday("15.08.2030")
    end

    test "A valid birthday with a 4 digit year is returned as a date" do
      assert {:ok, ~D[2005-08-15]} = BirthdayValidator.validate_birthday("15.08.2005")
    end

    test "A Valid birthday with a 2 digit year returns a date" do
      assert {:ok, ~D[2004-08-15]} = BirthdayValidator.validate_birthday("15.08.04")
    end

    test "A Valid birthday with a 1 digit year returns a date" do
      assert {:ok, ~D[2004-08-15]} = BirthdayValidator.validate_birthday("15.08.4")
    end

    test "A Valid birthday with a 1 digit day returns a date" do
      assert {:ok, ~D[2004-08-09]} = BirthdayValidator.validate_birthday("9.08.4")
    end

    test "A Valid birthday with a 1 digit month returns a date" do
      assert {:ok, ~D[2004-08-09]} = BirthdayValidator.validate_birthday("09.8.04")
    end

    test "A birthday less than 18 years ago returns an error" do
      assert {:error, "Birthday must be more than 18 years ago."} =
               BirthdayValidator.validate_birthday("15.08.2010")
    end
  end
end
