# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     IndiesShuffle.Repo.insert!(%IndiesShuffle.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias IndiesShuffle.Repo
alias IndiesShuffle.Questions.Question

# Seed sample questions
sample_questions = [
  %{
    text: "¿Cuál es tu color favorito?",
    category: "preferencias"
  },
  %{
    text: "¿Qué prefieres hacer en tu tiempo libre?",
    category: "preferencias"
  },
  %{
    text: "¿Cuál ha sido tu experiencia más memorable?",
    category: "experiencias"
  },
  %{
    text: "¿Cómo te describes a ti mismo?",
    category: "personalidad"
  },
  %{
    text: "¿Qué actividad te divierte más?",
    category: "diversion"
  }
]

Enum.each(sample_questions, fn question_data ->
  case Repo.get_by(Question, text: question_data.text) do
    nil ->
      %Question{}
      |> Question.changeset(question_data)
      |> Repo.insert!()
      IO.puts("Creada pregunta: #{question_data.text}")
    _existing ->
      IO.puts("Pregunta ya existe: #{question_data.text}")
  end
end)

IO.puts("✅ Base de datos poblada con datos de ejemplo")