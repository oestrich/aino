defmodule Aino.Request do
  @moduledoc false

  # Convert an `:elli` request record into a struct that we can work with easily

  record = Record.extract(:req, from_lib: "elli/include/elli.hrl")
  keys = :lists.map(&elem(&1, 0), record)
  vals = :lists.map(&{&1, [], nil}, keys)
  pairs = :lists.zip(keys, vals)

  defstruct keys

  def from_record({:req, unquote_splicing(vals)}) do
    %__MODULE__{unquote_splicing(pairs)}
  end

  def to_record(%Aino.Request{unquote_splicing(pairs)}) do
    {:req, unquote_splicing(vals)}
  end
end
