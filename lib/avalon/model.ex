defmodule Avalon.Model do
  @moduledoc """
  Represents an LLM model offered by a provider.
  Includes metadata about the model's capabilities, costs, and limitations.
  """

  defstruct [
    :name,
    :provider,
    :capabilities,
    :context_length,
    :cost_per_input_token,
    :cost_per_output_token,
    :metadata
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          provider: module(),
          capabilities:
            list(
              :chat
              | :embeddings
              | :transcription
              | :translation
              | :vision
              | :image_generation
              | :code_generation
              | :real_time_audio
              | :real_time_video
              | :tool_use
              | :structured_outputs
            ),
          context_length: integer(),
          cost_per_input_token: float(),
          cost_per_output_token: float(),
          metadata: map()
        }
end
