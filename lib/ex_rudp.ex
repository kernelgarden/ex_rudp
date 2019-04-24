defmodule ExRudp do
  @type state ::
          type_ping()
          | type_eof()
          | type_corrupt()
          | type_request()
          | type_missing()
          | type_normal()

  @type type_ping :: 0
  @type type_eof :: 1
  @type type_corrupt :: 2
  @type type_request :: 3
  @type type_missing :: 4
  @type type_normal :: 5

  def type_ping, do: 0

  def type_eof, do: 1

  def type_corrupt, do: 2

  def type_request, do: 3

  def type_missing, do: 4

  def type_normal, do: 5

  @type error :: {:error, error_detail()}

  @type error_detail :: nil | :remote_eof | :corrupt | :msg_size

  @max_msg_head 4
  @general_package 576 - 60 - 8
  @max_package 0x7FFF - 5

  def max_msg_head, do: @max_msg_head

  def general_package, do: @general_package

  def max_package, do: @max_package
end
