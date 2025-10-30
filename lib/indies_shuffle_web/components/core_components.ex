defmodule IndiesShuffleWeb.CoreComponents do
  @moduledoc """
  Provides custom UI components for Indies Shuffle.

  This module provides reusable UI components built specifically for the
  Indies Shuffle application. All components use pure Tailwind CSS classes
  without external dependencies.

  Components include:
  - Cards and containers
  - Buttons with multiple variants
  - Form inputs and labels
  - Badges and avatars
  - Custom icons

  """
  use Phoenix.Component
  use Gettext, backend: IndiesShuffleWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders a custom icon component using SVG.

  ## Examples

      <.ui_icon name="check" class="w-5 h-5" />
      <.ui_icon name="x-mark" class="w-4 h-4 text-red-500" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  def ui_icon(assigns) do
    ~H"""
    <svg class={[
      "fill-current w-6 h-6",
      @class
    ]} {@rest} viewBox="0 0 24 24">
      <%= case @name do %>
        <% "check" -> %>
          <path d="M20.285 2l-11.285 11.567-5.286-5.011-3.714 3.716 9 8.728 15-15.285z"/>
        <% "x-mark" -> %>
          <path d="M24 20.188l-8.315-8.209 8.2-8.282-3.697-3.697-8.212 8.318-8.31-8.203-3.666 3.666 8.321 8.24-8.206 8.313 3.666 3.666 8.237-8.318 8.285 8.203z"/>
        <% "exclamation-triangle" -> %>
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
        <% "check-circle" -> %>
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
        <% "cog" -> %>
          <path d="M19.14,12.94c0.04-0.3,0.06-0.61,0.06-0.94c0-0.32-0.02-0.64-0.07-0.94l2.03-1.58c0.18-0.14,0.23-0.41,0.12-0.61 l-1.92-3.32c-0.12-0.22-0.37-0.29-0.59-0.22l-2.39,0.96c-0.5-0.38-1.03-0.7-1.62-0.94L14.4,2.81c-0.04-0.24-0.24-0.41-0.48-0.41 h-3.84c-0.24,0-0.43,0.17-0.47,0.41L9.25,5.35C8.66,5.59,8.12,5.92,7.63,6.29L5.24,5.33c-0.22-0.08-0.47,0-0.59,0.22L2.74,8.87 C2.62,9.08,2.66,9.34,2.86,9.48l2.03,1.58C4.84,11.36,4.8,11.69,4.8,12s0.02,0.64,0.07,0.94l-2.03,1.58 c-0.18,0.14-0.23,0.41-0.12,0.61l1.92,3.32c0.12,0.22,0.37,0.29,0.59,0.22l2.39-0.96c0.5,0.38,1.03,0.7,1.62,0.94l0.36,2.54 c0.05,0.24,0.24,0.41,0.48,0.41h3.84c0.24,0,0.44-0.17,0.47-0.41l0.36-2.54c0.59-0.24,1.13-0.56,1.62-0.94l2.39,0.96 c0.22,0.08,0.47,0,0.59-0.22l1.92-3.32c0.12-0.22,0.07-0.47-0.12-0.61L19.14,12.94z M12,15.6c-1.98,0-3.6-1.62-3.6-3.6 s1.62-3.6,3.6-3.6s3.6,1.62,3.6,3.6S13.98,15.6,12,15.6z"/>
        <% "arrow-right" -> %>
          <path d="M8 5v14l11-7z"/>
        <% "logout" -> %>
          <path d="M17 7l-1.41 1.41L18.17 11H8v2h10.17l-2.58 2.59L17 17l5-5zM4 5h8V3H4c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h8v-2H4V5z"/>
        <% _ -> %>
          <circle cx="12" cy="12" r="10"/>
      <% end %>
    </svg>
    """
  end

  @doc """
  Renders a container with max-w-sm and vertical layout.

  ## Examples

      <.ui_container>
        <p>Content here</p>
      </.ui_container>

      <.ui_container class="bg-gray-50">
        Content with additional classes
      </.ui_container>
  """
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_container(assigns) do
    ~H"""
    <div class={[
      # Base styles
      "flex flex-col px-4",
      # If no custom class includes max-w, add default max-width
      (!String.contains?(@class || "", "max-w") && "max-w-sm mx-auto"),
      # If no custom class includes space-y, add default spacing
      (!String.contains?(@class || "", "space-y") && "space-y-4"),
      @class
    ]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card component.

  ## Examples

      <.ui_card>
        <p>Card content</p>
      </.ui_card>

      <.ui_card class="border-blue-200">
        <.ui_card_header>
          <h3>Card Title</h3>
        </.ui_card_header>
        <.ui_card_content>
          <p>Card body content</p>
        </.ui_card_content>
      </.ui_card>
  """
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_card(assigns) do
    ~H"""
    <div class={["bg-slate-900/95 backdrop-blur-md rounded-lg shadow-lg border border-slate-700", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card header.
  """
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_card_header(assigns) do
    ~H"""
    <div class={["px-4 py-3 border-b border-slate-700", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card content area.
  """
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_card_content(assigns) do
    ~H"""
    <div class={["px-4 py-4", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a card footer.
  """
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_card_footer(assigns) do
    ~H"""
    <div class={["px-4 py-3 border-t border-slate-700 bg-slate-800/50 rounded-b-lg", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a button component.

  ## Examples

      <.ui_button>Click me</.ui_button>

      <.ui_button variant="secondary">Secondary</.ui_button>

      <.ui_button size="lg" phx-click="do_something">
        Large Button
      </.ui_button>
  """
  attr :variant, :string, default: "primary", values: ~w(primary secondary outline ghost danger)
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :type, :string, default: "button"
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled form name value)
  slot :inner_block, required: true

  def ui_button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        # Base styles
        "inline-flex items-center justify-center gap-1 font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:pointer-events-none",
        # Size variants
        @size == "sm" && "px-3 py-1.5 text-sm",
        @size == "md" && "px-4 py-2 text-sm",
        @size == "lg" && "px-6 py-3 text-base",
        # Color variants
        @variant == "primary" && "bg-orange-600 text-white hover:bg-orange-700 focus:ring-orange-500",
        @variant == "secondary" && "bg-gray-800 text-white hover:bg-gray-900 focus:ring-gray-500",
        @variant == "outline" && "border border-orange-600 bg-white text-orange-600 hover:bg-orange-50 focus:ring-orange-500",
        @variant == "ghost" && "text-gray-700 hover:bg-orange-50 focus:ring-orange-500",
        @variant == "danger" && "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders an input field.

  ## Examples

      <.ui_input name="email" placeholder="Enter email" />

      <.ui_input name="message" type="textarea" rows="4" />
  """
  attr :name, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: ""
  attr :value, :string, default: ""
  attr :autocomplete, :string, default: ""
  attr :maxlength, :integer, default: nil
  attr :required, :boolean, default: false
  attr :rows, :integer, default: 3
  attr :class, :string, default: ""
  attr :rest, :global

  def ui_input(assigns) do
    cond do
      assigns.type == "textarea" ->
        ~H"""
        <textarea
          name={@name}
          placeholder={@placeholder}
          value={@value}
          rows={@rows}
          maxlength={@maxlength}
          required={@required}
          autocomplete={@autocomplete}
          class={[
            "block w-full rounded-md border-gray-300 shadow-sm focus:border-orange-500 focus:ring-orange-500 sm:text-sm px-4 py-2 text-black",
            @class
          ]}
          {@rest}
        ><%= @value %></textarea>
        """

      true ->
        ~H"""
        <input
          type={@type}
          name={@name}
          placeholder={@placeholder}
          value={@value}
          maxlength={@maxlength}
          required={@required}
          autocomplete={@autocomplete}
          class={[
            "block w-full rounded-md border-gray-300 shadow-sm focus:border-orange-500 focus:ring-orange-500 sm:text-sm text-black px-4 py-2",
            @class
          ]}
          {@rest}
        />
        """
    end
  end

  @doc """
  Renders a label for form inputs.
  """
  attr :for, :string, default: ""
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_label(assigns) do
    ~H"""
    <label for={@for} class={["block text-sm font-medium text-gray-700", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Renders a badge component.

  ## Examples

      <.ui_badge>New</.ui_badge>

      <.ui_badge variant="success">Active</.ui_badge>
  """
  attr :variant, :string, default: "default", values: ~w(default success warning danger info)
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  def ui_badge(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
        @variant == "default" && "bg-gray-100 text-gray-800",
        @variant == "success" && "bg-orange-100 text-orange-800",
        @variant == "warning" && "bg-yellow-100 text-yellow-800",
        @variant == "danger" && "bg-red-100 text-red-800",
        @variant == "info" && "bg-gray-800 text-white",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </span>
    """
  end

  @doc """
  Renders an avatar component.

  ## Examples

      <.ui_avatar name="John Doe" />

      <.ui_avatar src="/images/avatar.jpg" name="John Doe" size="lg" />
  """
  attr :src, :string, default: nil
  attr :name, :string, required: true
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :class, :string, default: ""
  attr :rest, :global

  def ui_avatar(assigns) do
    initials =
      assigns.name
      |> String.split()
      |> Enum.take(2)
      |> Enum.map(&String.first/1)
      |> Enum.join()
      |> String.upcase()

    assigns = assign(assigns, :initials, initials)

    ~H"""
    <div
      class={[
        "inline-flex items-center justify-center rounded-full bg-orange-600 text-white font-medium",
        @size == "sm" && "h-8 w-8 text-sm",
        @size == "md" && "h-10 w-10 text-sm",
        @size == "lg" && "h-12 w-12 text-base",
        @class
      ]}
      {@rest}
    >
      <%= if @src do %>
        <img src={@src} alt={@name} class="h-full w-full rounded-full object-cover" />
      <% else %>
        <%= @initials %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a flash message.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
  """
  attr :id, :string, default: nil, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :class, :string, default: ""
  attr :rest, :global, doc: "the arbitrary HTML attributes to apply to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class={[
        "fixed top-2 right-2 mr-2 w-80 sm:w-96 z-50 rounded-lg p-3 ring-1",
        @kind == :info && "bg-emerald-50 text-emerald-800 ring-emerald-500 fill-cyan-900",
        @kind == :error && "bg-rose-50 text-rose-900 shadow-md ring-rose-500 fill-rose-900",
        @class
      ]}
      {@rest}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-check" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-x-mark" class="h-4 w-4" />
        {@title}
      </p>
      <p class="mt-2 text-sm leading-5">{msg}</p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <.icon name="hero-x-mark" class="h-5 w-5 opacity-40 group-hover:opacity-70" />
      </button>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-right" class="ml-1 size-3" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-right" class="ml-1 size-3" />
      </.flash>
    </div>
    """
  end

  @doc """
  Shows an element.

  ## Examples

      show("#modal")
  """
  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  @doc """
  Hides an element.

  ## Examples

      hide("#modal")
  """
  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders an icon from Heroicons library.
  Icons should be specified using the heroicon name (e.g., "hero-check", "hero-x-mark").
  """
  attr :name, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  def icon(assigns) do
    # Convert hero- prefix to proper heroicon names and map to available icons
    icon_name = case assigns.name do
      "hero-" <> name -> name
      name -> name
    end

    # Map to actual heroicon file names
    actual_icon = case icon_name do
      "check" -> "check"
      "x-mark" -> "x-mark"
      "cog-6-tooth" -> "cog-6-tooth"
      "exclamation-triangle" -> "exclamation-triangle"
      "arrow-right" -> "arrow-right"
      "arrow-right-end-on-rectangle" -> "arrow-right-end-on-rectangle"
      "pencil" -> "pencil"
      "play" -> "play"
      "check-circle" -> "check-circle"
      "x-circle" -> "x-circle"
      other -> other
    end

    assigns = assign(assigns, :icon_name, actual_icon)

    ~H"""
    <svg class={["w-4 h-4 ", @class]} {@rest} fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
      <%= case @icon_name do %>
        <% "check" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="m4.5 12.75 6 6 9-13.5" />
        <% "x-mark" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12" />
        <% "cog-6-tooth" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z" />
          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
        <% "exclamation-triangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126ZM12 15.75h.007v.008H12v-.008Z" />
        <% "arrow-right" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3" />
        <% "arrow-right-end-on-rectangle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 9V5.25A2.25 2.25 0 0 1 10.5 3h6a2.25 2.25 0 0 1 2.25 2.25v13.5A2.25 2.25 0 0 1 16.5 21h-6a2.25 2.25 0 0 1-2.25-2.25V15M12 9l3 3m0 0-3 3m3-3H2.25" />
        <% "pencil" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Zm0 0L19.5 7.125" />
        <% "play" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z" />
        <% "check-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75 11.25 15 15 9.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        <% "x-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="m9.75 9.75 4.5 4.5m0-4.5-4.5 4.5M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        <% _ -> %>
          <!-- Default fallback icon -->
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" />
      <% end %>
    </svg>
    """
  end

  @doc """
  Renders a logout confirmation modal.

  ## Examples

      <.logout_modal show={@show_logout_modal} />
  """
  attr :show, :boolean, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  def logout_modal(assigns) do
    ~H"""
    <%= if @show do %>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center"
        phx-window-keydown="hide_logout_modal"
        phx-key="escape"
      >
        <!-- Backdrop -->
        <div
          class="absolute inset-0 bg-black opacity-40 backdrop-blur-lg"
          phx-click="hide_logout_modal"
        ></div>

        <!-- Modal -->
        <div class="relative bg-white rounded-lg shadow-xl p-6 m-4 max-w-sm w-full">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Confirmar Cierre de Sesión</h3>
          <p class="text-gray-600 mb-6">¿Estás seguro de que quieres cerrar tu sesión?</p>

          <div class="flex space-x-3">
            <.ui_button
              variant="outline"
              class="flex-1"
              phx-click="hide_logout_modal"
            >
              Cancelar
            </.ui_button>
            <.ui_button
              variant="danger"
              class="flex-1"
              phx-click="confirm_logout"
            >
              Cerrar Sesión
            </.ui_button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
