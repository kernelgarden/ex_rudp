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

  @type error_detail ::
          error_nil()
          | error_eof()
          | error_remote_eof()
          | error_corrupt()
          | error_msg_size()

  @type error_nil :: 0
  @type error_eof :: 1
  @type error_remote_eof :: 2
  @type error_corrupt :: 3
  @type error_msg_size :: 4

  def error_nil, do: 0

  def error_eof, do: 1

  def error_remote_eof, do: 2

  def error_corrupt, do: 3

  def error_msg_size, do: 4

  @max_msg_head 4
  @general_package 576 - 60 - 8
  @max_package 0x7FFF - 5

  def max_msg_head, do: @max_msg_head

  def general_package, do: @general_package

  def max_package, do: @max_package

  @corrupt_tick 5
  # 5 min * tick per sec
  @expired_tick 100 * 60 * 5
  @send_delay_tick 1
  @missing_time 10_000_000

  def corrupt_tick, do: @corrupt_tick

  def expired_tick, do: @expired_tick

  def send_delay_tick, do: @send_delay_tick

  def missing_time, do: @missing_time
end
