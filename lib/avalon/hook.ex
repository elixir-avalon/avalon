defmodule Avalon.Hook do
  @callback pre_message(context :: map(), message :: Message.t(), opts :: keyword()) ::
              {:ok, context :: map()} | {:error, term()}

  @callback post_message(context :: map(), message :: Message.t(), opts :: keyword()) ::
              {:ok, context :: map()} | {:error, term()}

  @callback pre_node(context :: map(), node :: Node.t(), input :: term(), opts :: keyword()) ::
              {:ok, context :: map()} | {:error, term()}

  @callback post_node(context :: map(), node :: Node.t(), result :: term(), opts :: keyword()) ::
              {:ok, context :: map()} | {:error, term()}

  @callback pre_workflow(context :: map(), workflow :: Workflow.t(), opts :: keyword()) ::
              {:ok, context :: map()} | {:error, term()}

  @callback post_workflow(
              context :: map(),
              workflow :: Workflow.t(),
              result :: term(),
              opts :: keyword()
            ) ::
              {:ok, context :: map()} | {:error, term()}

  @optional_callbacks [
    pre_message: 3,
    post_message: 3,
    pre_node: 4,
    post_node: 4,
    pre_workflow: 3,
    post_workflow: 4
  ]
end
