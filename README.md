# Avalon

Avalon is a standardisation framework for building agentic workflows in Elixir. It provides composable primitive building blocks that enable the creation of flexible, modular AI agent systems. In Elixir, the language is the framework.

## Overview

Avalon focuses on standardisation rather than batteries-included functionality. The library defines behaviors, structs, and protocols that serve as the foundation for building agentic workflows. It's designed to be highly pluggable, allowing you to integrate with various LLM providers, tools, and custom components.

Taking inspiration from established frameworks like LangGraph and SmolAgents, Avalon brings structured agentic workflows to the Elixir ecosystem while embracing Elixir's strengths in building concurrent, fault-tolerant systems.

## Table of Contents

- [Installation](#installation)
- [Architecture](#architecture)
- [Core Components](#core-components)
- [Design Philosophy](#design-philosophy)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Installation

If available in Hex, the package can be installed by adding `avalon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:avalon, "~> 0.1.0"}
  ]
end
```

## Architecture

Avalon is architected around the concept of composable, standardised components for agentic workflows. The key architectural patterns include:

### Conversational Agents

Provides standardised structures for representing, storing, and manipulating conversations with LLMs through a `Conversation` module and related components.

### Provider Abstraction

A pluggable system for interacting with different LLM providers (OpenAI, Anthropic, etc.) through a unified interface.

### Tool Integration

Defines standards for tool creation, allowing agents to interact with external systems and data sources.

### Workflows

A graph-based workflow engine that enables complex, multi-step agent processes with:
- Nodes representing individual units of work
- Edges defining the flow between nodes
- Routers determining conditional paths
- Visualisers for workflow inspection and debugging

## Core Components

Avalon consists of several core components:

**Conversations and Messages**: Structured representations of agent-LLM interactions.

**Providers**: Abstractions for different LLM services.

**Tools**: Standardised interfaces for agent capabilities, like the included Calculator tool.

**Workflows**: Directed graphs of operations that can be composed into complex agent behaviors.

**Hooks**: Extensible points for custom behavior at various stages of execution.

## Design Philosophy

Avalon's design follows these key principles:

1. **Standardisation over Implementation**: Focus on defining clear interfaces that can be implemented in various ways.

2. **Composability**: All components should be easily composed into more complex systems.

3. **Pluggability**: Support for easy integration with different LLM providers, tools, and custom components.

4. **Elixir-native**: Embracing Elixir's concurrency model and OTP principles for reliable agentic systems.

5. **Separation of Concerns**: Clear boundaries between different aspects of agent functionality.

## Roadmap

Avalon is a work in progress. The following features are planned for future releases:

- **Process-based agents**: Leveraging OTP for agent lifecycles.
- **Persistent Storage**: Standard building blocks for conversation and state persistence.
- **Multi-agent Coordination**: Better support for multiple agents working together.
- **Observability and Monitoring**: Tools for tracking and debugging agent operations.
- **Memory Management**: More sophisticated context and knowledge management.
- **Advanced Workflow Patterns**: Additional workflow patterns and templates.

## Contributing

Contributions are welcome! Since Avalon is focused on standardisation, contributions that enhance the interfaces, documentation, and examples are particularly valuable.

## License

 Copyright 2025 Christopher Grainger

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
