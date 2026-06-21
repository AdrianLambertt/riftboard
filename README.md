# Riftboard

Riftboard is a real-time kanban/issue board built as a portfolio project to showcase Elixir/Phoenix/LiveView experience.

## Features

- Create and manage multiple boards
- Add, reorder, and delete columns
- Add, edit, and delete cards with titles and descriptions
- Drag-and-drop card reordering across columns (Sortable.js)
- Live validation on all forms

## Tech stack

- **Elixir / Phoenix 1.7** — backend and routing
- **Phoenix LiveView 1.0** — real-time UI without writing JavaScript
- **Ecto / PostgreSQL** — data persistence with transactional card reordering
- **Tailwind CSS** — styling
- **Sortable.js** — drag-and-drop via a Phoenix JS hook

## Running locally

You'll need Elixir, Erlang, and PostgreSQL installed.

```bash
# Install dependencies
mix setup

# Start the server
mix phx.server
```

## Quality

Unit and Liveview tests
Utilises credo and dialyzer for type safety and code analysis/standard
