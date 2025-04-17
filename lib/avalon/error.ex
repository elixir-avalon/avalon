defmodule Avalon.Error do
  @moduledoc """
  Standardized error structure for Avalon operations.
  """
  defstruct [
    # Error category (e.g. :provider, :validation, :tool)
    :type,
    # Human-readable error description
    :message,
    # Additional context (raw response, params, provider, etc.)
    :metadata
  ]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          metadata: map()
        }
end
