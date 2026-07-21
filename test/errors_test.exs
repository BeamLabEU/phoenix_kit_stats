defmodule PhoenixKitStats.ErrorsTest do
  use ExUnit.Case, async: true

  alias PhoenixKitStats.Errors

  test "maps known atoms to human-readable strings" do
    for atom <- [
          :group_not_found,
          :key_taken,
          :port_taken,
          :port_out_of_range,
          :listener_start_failed,
          :group_delete_failed,
          :unexpected
        ] do
      message = Errors.message(atom)
      assert is_binary(message)
      assert message != ""
    end
  end

  test "passes through binary reasons unchanged" do
    assert Errors.message("already a message") == "already a message"
  end

  test "falls back to an inspected message for unknown reasons" do
    message = Errors.message({:weird, :reason})
    assert message =~ "Unexpected error"
    assert message =~ "weird"
  end
end
