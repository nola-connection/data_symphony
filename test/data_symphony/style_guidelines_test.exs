defmodule DataSymphony.StyleGuidelinesTest do
  @moduledoc """
  Guards F-7: Elixir style & architecture guidelines acceptance criteria.

  1. Guidelines doc committed (`docs/`), linked from the README/contributing.
  2. Covers architecture, context grouping/boundaries, naming, and process
     conventions with concrete examples.
  3. Credo config reflects the agreed rules where they can be automated.
  4. Reviewed and agreed by the team as the canonical reference. The human
     agreement happens on the PR; here we verify the doc positions itself as the
     canonical reference and is linked as such.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)
  @doc_path "docs/09-style-and-architecture-guidelines.md"

  defp read(relative), do: File.read!(Path.join(@root, relative))
  defp exists?(relative), do: File.exists?(Path.join(@root, relative))

  # The portion of .credo.exs before the `disabled:` key — checks listed here
  # are actually enforced by `mix credo --strict`.
  defp credo_enabled_section do
    @root
    |> Path.join(".credo.exs")
    |> File.read!()
    |> String.split("disabled:")
    |> List.first()
  end

  describe "criterion 1: doc committed and linked" do
    test "the guidelines doc exists under docs/" do
      assert exists?(@doc_path)
    end

    test "the root README links to the guidelines doc" do
      assert read("README.md") =~ @doc_path
    end

    test "the docs index links to the guidelines doc" do
      assert read("docs/README.md") =~ "09-style-and-architecture-guidelines.md"
    end
  end

  describe "criterion 2: covers required topics with concrete examples" do
    setup do
      {:ok, doc: read(@doc_path)}
    end

    test "covers architecture and directory/module structure", %{doc: doc} do
      assert doc =~ "## Directory & module structure"
      assert doc =~ "DataSymphony.*"
      assert doc =~ "DataSymphonyWeb.*"
    end

    test "covers context grouping and boundaries", %{doc: doc} do
      assert doc =~ "## Contexts, schemas, and pure modules"
      assert doc =~ "Cross-context calls"
      assert doc =~ "Schemas never call the `Repo`"
    end

    test "covers naming conventions", %{doc: doc} do
      assert doc =~ "## Naming conventions"
      assert doc =~ "snake_case"
      assert doc =~ "CamelCase"
      assert doc =~ "Worker"
    end

    test "covers process and supervision conventions, incl. when not to", %{doc: doc} do
      assert doc =~ "## Process & supervision conventions"
      assert doc =~ "Oban"
      assert doc =~ "Phoenix.PubSub"
      assert doc =~ "Do _not_ introduce a process"
    end

    test "includes concrete code examples", %{doc: doc} do
      assert doc =~ "```elixir"
    end
  end

  describe "criterion 3: credo reflects the automatable rules" do
    test "agreed automatable checks are enabled, not disabled" do
      enabled = credo_enabled_section()

      for check <- [
            "Credo.Check.Readability.ModuleNames",
            "Credo.Check.Readability.FunctionNames",
            "Credo.Check.Readability.PredicateFunctionNames",
            "Credo.Check.Readability.AliasOrder",
            "Credo.Check.Readability.ModuleDoc",
            "Credo.Check.Readability.StrictModuleLayout",
            "Credo.Check.Readability.SinglePipe",
            "Credo.Check.Refactor.UnlessWithElse"
          ] do
        assert enabled =~ check, "#{check} should be enabled in .credo.exs"
      end
    end

    test "the doc points readers to .credo.exs as the enforcement mechanism" do
      doc = read(@doc_path)
      assert doc =~ "## How this maps to Credo"
      assert doc =~ ".credo.exs"
    end
  end

  describe "criterion 4: positioned as the canonical reference" do
    test "the doc declares itself the canonical reference" do
      assert read(@doc_path) =~ "canonical reference"
    end

    test "the README frames the doc as the reference reviewers point to" do
      assert read("README.md") =~ "Style & Architecture Guidelines"
    end
  end
end
