defmodule IndiesShuffle.Repo.Migrations.CreateQuestions do
  use Ecto.Migration

  def change do
    create table(:questions) do
      add :category, :string, null: false
      add :text, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:category])
    create unique_index(:questions, ["lower(text)"], name: :questions_text_index)

    flush()
    # seed_default_questions()
  end

  defp seed_default_questions do
    now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()

    entries =
      IndiesShuffle.Game.QuestionSet.default_questions()
      |> Enum.flat_map(fn {category, questions} ->
        Enum.map(questions, fn text ->
          %{
            category: Atom.to_string(category),
            text: text,
            inserted_at: now,
            updated_at: now
          }
        end)
      end)

    if entries != [] do
      repo().insert_all("questions", entries, on_conflict: :nothing)
    end
  end
end
