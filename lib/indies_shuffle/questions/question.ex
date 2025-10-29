defmodule IndiesShuffle.Questions.Question do
  @moduledoc """
  Ecto schema representing a stored question for the questions game.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @categories [:preferencias, :experiencias, :personalidad, :diversion]

  schema "questions" do
    field :category, Ecto.Enum, values: @categories, default: :preferencias
    field :text, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid categories.
  """
  def categories, do: @categories

  @doc """
  Builds a changeset for creating or updating a question.
  """
  def changeset(question, attrs) do
    question
    |> cast(attrs, [:category, :text])
    |> update_change(:text, fn
      nil -> nil
      value -> String.trim(value)
    end)
    |> validate_required([:category, :text])
    |> validate_length(:text, min: 5, max: 500)
    |> unique_constraint(:text, name: :questions_text_index, message: "La pregunta ya existe")
  end
end
