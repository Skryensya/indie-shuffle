defmodule IndiesShuffle.Questions do
  @moduledoc """
  Context for managing questions stored in the database.
  """
  import Ecto.Query, warn: false
  alias IndiesShuffle.Repo

  alias IndiesShuffle.Questions.Question

  @doc """
  Lists all questions ordered from newest to oldest.
  """
  def list_questions(opts \\ []) do
    Question
    |> maybe_filter_category(opts)
    |> order_by([q], desc: q.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists questions grouped by category.
  """
  def list_questions_grouped do
    Question
    |> order_by([q], desc: q.inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.category)
  end

  @doc """
  Fetches a question by ID. Returns nil when not found.
  """
  def get_question(id), do: Repo.get(Question, id)

  @doc """
  Fetches a question by ID. Raises when not found.
  """
  def get_question!(id), do: Repo.get!(Question, id)

  @doc """
  Creates a question from the given attributes.
  """
  def create_question(attrs \\ %{}) do
    %Question{}
    |> Question.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a question.
  """
  def update_question(%Question{} = question, attrs) do
    question
    |> Question.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a question.
  """
  def delete_question(%Question{} = question) do
    Repo.delete(question)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking question changes.
  """
  def change_question(%Question{} = question, attrs \\ %{}) do
    Question.changeset(question, attrs)
  end

  @doc """
  Returns a random set of questions text.
  """
  def random_questions(limit) when limit > 0 do
    Question
    |> order_by(fragment("RANDOM()"))
    |> limit(^limit)
    |> Repo.all()
  end

  def random_questions(_limit), do: []

  defp maybe_filter_category(query, opts) do
    case Keyword.get(opts, :category) do
      nil -> query
      category when is_atom(category) -> from(q in query, where: q.category == ^category)
      category when is_binary(category) ->
        case safe_to_atom(category) do
          {:ok, atom_category} -> from(q in query, where: q.category == ^atom_category)
          :error -> from(q in query, where: false)
        end
    end
  end

  defp safe_to_atom(value) do
    value
    |> String.to_existing_atom()
    |> then(&{:ok, &1})
  rescue
    ArgumentError -> :error
  end
end
