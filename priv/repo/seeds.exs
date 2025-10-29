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
    type: "multiple_choice",
    options: ["Azul", "Rojo", "Verde", "Amarillo"],
    correct_answer: nil,
    category: "personal"
  },
  %{
    text: "¿Qué prefieres hacer en tu tiempo libre?",
    type: "multiple_choice", 
    options: ["Leer", "Ver películas", "Hacer ejercicio", "Cocinar"],
    correct_answer: nil,
    category: "personal"
  },
  %{
    text: "¿Cuántos continentes hay en el mundo?",
    type: "multiple_choice",
    options: ["5", "6", "7", "8"],
    correct_answer: "7",
    category: "trivia"
  }
]

Enum.each(sample_questions, fn question_data ->
  %Question{}
  |> Question.changeset(question_data)
  |> Repo.insert!()
end)

IO.puts("✅ Base de datos poblada con datos de ejemplo")