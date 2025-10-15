defmodule IndiesShuffle.Game.PuzzleEngine do
  @moduledoc """
  Generates puzzle combinations and rules for the combination game.
  Players must find the correct figure + color + style combination.
  """

  @figures [:circle, :square, :triangle, :diamond, :star, :hexagon]
  @colors [:red, :blue, :green, :yellow, :purple, :orange]
  @styles [:filled, :outline, :dashed]

  @doc """
  Generates a random secret combination that players must discover.
  """
  def random_secret do
    %{
      figure: Enum.random(@figures),
      color: Enum.random(@colors),
      style: Enum.random(@styles)
    }
  end

  @doc """
  Generates a set of validation rules based on the secret combination.
  These rules will be distributed among players as clues.
  """
  def generate_rules(secret) do
    base_rules = [
      rule("Red figures are never circles.",
        fn combo -> not (combo.color == :red and combo.figure == :circle) end),
      
      rule("Blue shapes must be filled or outline, never dashed.",
        fn combo -> if combo.color == :blue, do: combo.style != :dashed, else: true end),
      
      rule("Triangles are never yellow.",
        fn combo -> not (combo.figure == :triangle and combo.color == :yellow) end),
      
      rule("Purple shapes can only be stars or diamonds.",
        fn combo -> if combo.color == :purple, do: combo.figure in [:star, :diamond], else: true end),
      
      rule("Dashed styles are only for squares and hexagons.",
        fn combo -> if combo.style == :dashed, do: combo.figure in [:square, :hexagon], else: true end),
      
      rule("Green figures must be outline style.",
        fn combo -> if combo.color == :green, do: combo.style == :outline, else: true end),
      
      rule("Circles can never be orange.",
        fn combo -> not (combo.figure == :circle and combo.color == :orange) end),
      
      rule("Stars are always filled or dashed, never outline.",
        fn combo -> if combo.figure == :star, do: combo.style != :outline, else: true end)
    ]

    # Filter rules that the secret combination satisfies
    valid_rules = Enum.filter(base_rules, fn rule -> rule.applies?.(secret) end)
    
    # Take 5-6 rules to distribute among players
    Enum.take_random(valid_rules, Enum.random(5..6))
  end

  @doc """
  Creates a rule with text description and validation function.
  """
  def rule(text, validation_fn) do
    %{text: text, applies?: validation_fn}
  end

  @doc """
  Checks if a combination satisfies all given rules.
  """
  def satisfies_all?(combination, rules) do
    Enum.all?(rules, fn rule -> rule.applies?.(combination) end)
  end

  @doc """
  Returns all possible figures.
  """
  def figures, do: @figures

  @doc """
  Returns all possible colors.
  """
  def colors, do: @colors

  @doc """
  Returns all possible styles.
  """
  def styles, do: @styles

  @doc """
  Validates if a combination is properly formed.
  """
  def valid_combination?(%{figure: figure, color: color, style: style}) do
    figure in @figures and color in @colors and style in @styles
  end
  def valid_combination?(_), do: false
end