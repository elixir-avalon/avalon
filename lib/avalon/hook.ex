defprotocol Avalon.Hook do
  @fallback_to_any true
  def pre_process(hook, context, data)
  def post_process(hook, context, data, result)
end

defimpl Avalon.Hook, for: Any do
  def pre_process(_hook, context, _data), do: {:ok, context}
  def post_process(_hook, context, _data, _result), do: {:ok, context}
end
