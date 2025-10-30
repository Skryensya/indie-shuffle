defmodule IndiesShuffle.Game.Questions do
  @moduledoc """
  Banco de preguntas predefinidas para presentar a los grupos.
  """

  @questions [
    "¿Cuál es tu superpoder secreto que nadie conoce?",
    "Si pudieras vivir en cualquier época, ¿cuál sería y por qué?",
    "¿Qué harías si ganaras la lotería mañana?",
    "¿Cuál es la experiencia más extraña que has tenido?",
    "Si pudieras tener cena con 3 personas (vivas o muertas), ¿quiénes serían?",
    "¿Qué consejo le darías a tu yo de hace 10 años?",
    "¿Cuál es tu teoría conspirativa favorita?",
    "Si pudieras aprender cualquier habilidad instantáneamente, ¿cuál sería?",
    "¿Qué película o serie has visto más veces?",
    "¿Cuál es el mejor regalo que has recibido?",
    "¿Qué tradición familiar extraña tienes?",
    "Si pudieras eliminar una cosa del mundo, ¿qué sería?",
    "¿Cuál es la mentira más grande que has dicho?",
    "¿Qué trabajo nunca harías sin importar cuánto paguen?",
    "¿Cuál es tu miedo irracional?",
    "Si pudieras cambiar una decisión del pasado, ¿cuál sería?",
    # Nuevas preguntas añadidas
    "¿Qué palabra te describiría mejor como emprendedor?",
    "¿Canción favorita para motivarte en el trabajo?",
    "Si pudiera vivir en cualquier país, ¿cuál sería?",
    "¿Cuál es tu sobrenombre o apodo?",
  ]

  @doc """
  Selecciona una pregunta aleatoria del banco.
  """
  def random_question do
    Enum.random(@questions)
  end

  @doc """
  Retorna todas las preguntas disponibles.
  """
  def all_questions, do: @questions

  @doc """
  Retorna el número total de preguntas.
  """
  def count, do: length(@questions)

  @doc """
  Agrega una nueva pregunta al banco (solo en memoria durante la sesión).
  """
  def add_question(_question) do
    # En la versión hardcodeada, no permitimos agregar preguntas
    {:error, "No se pueden agregar preguntas en esta versión"}
  end

  @doc """
  Remueve una pregunta del banco (solo en memoria durante la sesión).
  """
  def remove_question(_question) do
    # En la versión hardcodeada, no permitimos remover preguntas
    {:error, "No se pueden eliminar preguntas en esta versión"}
  end
end
